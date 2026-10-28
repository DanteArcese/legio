extends RefCounted
## Gathering and artisan actions: mining rocks, chopping trees, fishing,
## and making things (smelting at a furnace, smithing at an anvil, cooking
## at a range or campfire, inscribing curse tablets at a tomb, fletching
## anywhere). Actions repeat on ticks, OSRS-style, until done or interrupted.

const ContentDB := preload("res://scripts/content/content_db.gd")

## How close a player must stay to the rock, tree, spot, or station.
const ACTION_RANGE := 2.2
## Fishing spots sit in the water, so the shore can be a little farther off.
const FISHING_RANGE := 3.0
## Ticks between mining and chopping attempts, by tool tier. Steel (3) is
## as fast as iron but lands more often (MINE_CHANCE_PER_TIER).
const MINE_TICKS := {1: 4, 2: 3, 3: 3}
const CHOP_TICKS := {1: 4, 2: 3, 3: 3}
const FISH_TICKS := 5
const CRAFT_TICKS := 4
## Our own gathering formula: chance per attempt.
const MINE_BASE_CHANCE := 0.35
const MINE_CHANCE_PER_LEVEL := 0.015
const MINE_CHANCE_PER_TIER := 0.1
const FISH_BASE_CHANCE := 0.3
## What each fishing tool is called, for messages.
const FISHING_TOOLS := {"net": "small net", "rod": "fishing rod", "harpoon": "harpoon", "pot": "eel pot"}
## Burn chance at the recipe's level, falling to 0 at its stop_burning level.
const MAX_BURN_CHANCE := 0.5
## Where each kind of recipe is made. Fletching needs no station.
const STATIONS_FOR_KIND := {"smelt": ["furnace"], "smith": ["anvil"], "cook": ["range", "fire"], "inscribe": ["tomb"], "fletch": [],
	"tan": ["tanning_rack"], "leatherwork": [], "garum": ["garum_vat"], "medicina": [], "saw": ["sawpit"],
	"throw": ["potters_wheel"], "kiln": ["kiln"], "jewelcraft": [], "press_oil": ["olive_press"], "press_wine": ["wine_press"], "mill": ["quern"], "masonry": []}
const SKILL_FOR_KIND := {"smelt": "smithing", "smith": "smithing", "cook": "cooking", "inscribe": "ritus", "fletch": "fletching",
	"tan": "crafting", "leatherwork": "crafting", "garum": "cooking", "medicina": "medicina", "saw": "engineering",
	"throw": "crafting", "kiln": "crafting", "jewelcraft": "crafting", "press_oil": "cooking", "press_wine": "cooking", "mill": "cooking", "masonry": "crafting"}
## Recipe kinds made anywhere, from the inventory, and the verb for each.
const HANDHELD_KINDS := {"fletch": "Fletch", "leatherwork": "Sew", "medicina": "Mix", "jewelcraft": "Work", "masonry": "Carve"}

## Held weakly: the simulation owns this module, so a strong reference back
## would form a cycle that is never freed.
var sim: RefCounted:
	get:
		return _sim_ref.get_ref()
	set(value):
		_sim_ref = weakref(value)
var _sim_ref: WeakRef
## rock id -> {"id", "type", "position", "depleted_until"}
var rocks := {}
## tree id -> {"id", "type", "position", "felled_until"}
var trees := {}
## spot id -> {"id", "type", "position"}
var fishing_spots := {}
## [{"kind": "furnace" | "anvil" | "range", "position": Vector3}]
var stations: Array[Dictionary] = []


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


func add_rock(id: int, rock_type: String, position: Vector3) -> void:
	rocks[id] = {"id": id, "type": rock_type, "position": position, "depleted_until": -1}


func add_tree(id: int, tree_type: String, position: Vector3) -> void:
	trees[id] = {"id": id, "type": tree_type, "position": position, "felled_until": -1}


func add_fishing_spot(id: int, spot_type: String, position: Vector3) -> void:
	fishing_spots[id] = {"id": id, "type": spot_type, "position": position}


func add_station(kind: String, position: Vector3) -> void:
	stations.append({"kind": kind, "position": position})


static func mine_chance(level: int, rock: Dictionary, tool_tier: int) -> float:
	return gather_chance(level, rock["level"], rock["difficulty"], tool_tier)


## Chance per attempt for mining and woodcutting: better with level and tool.
static func gather_chance(level: int, required: int, difficulty: float, tool_tier: int, base := MINE_BASE_CHANCE) -> float:
	var chance: float = base + MINE_CHANCE_PER_LEVEL * (level - required) \
		+ MINE_CHANCE_PER_TIER * (tool_tier - 1) - difficulty
	return clampf(chance, 0.05, 0.95)


static func burn_chance(level: int, recipe: Dictionary) -> float:
	if not recipe.has("stop_burning") or level >= recipe["stop_burning"]:
		return 0.0
	var span := float(recipe["stop_burning"] - recipe["level"])
	return MAX_BURN_CHANCE * (recipe["stop_burning"] - level) / maxf(span, 1.0)


## Best usable tool tier of a kind the player carries or wears, or 0.
static func tool_tier(player: RefCounted, tool: String) -> int:
	var best := 0
	var owned: Array = player.inventory.slots.filter(func(s): return s != null).map(func(s): return s["item"])
	owned.append_array(player.equipment.worn.values())
	for item_id in owned:
		var item: Dictionary = ContentDB.item(item_id)
		if item.get("tool", "") != tool:
			continue
		var met := true
		var requirements: Dictionary = item.get("requirements", {})
		for skill in requirements:
			met = met and player.skills.level(skill) >= requirements[skill]
		if met:
			best = maxi(best, item["tool_tier"])
	return best


# --- Commands -----------------------------------------------------------

func start_mining(player: RefCounted, rock_id: int, events: Array) -> void:
	var rock: Dictionary = rocks.get(rock_id, {})
	if rock.is_empty() or _distance(player.position, rock["position"]) > ACTION_RANGE:
		return
	var data := ContentDB.rock(rock["type"])
	if player.skills.level("mining") < data["level"]:
		sim.message(player, "You need Mining %d to mine this." % data["level"], events)
		return
	var tier := tool_tier(player, "pickaxe")
	if tier == 0:
		sim.message(player, "You need a pickaxe you can use.", events)
		return
	if rock["depleted_until"] != -1:
		sim.message(player, "There is no ore left in this rock.", events)
		return
	player.target_id = -1
	player.skill_action = {"type": "mine", "rock": rock_id, "next_tick": sim.tick + MINE_TICKS[tier]}
	events.append({"type": "skill_started", "id": player.id, "action": "mine", "tick": sim.tick})


func start_chopping(player: RefCounted, tree_id: int, events: Array) -> void:
	var tree: Dictionary = trees.get(tree_id, {})
	if tree.is_empty() or _distance(player.position, tree["position"]) > ACTION_RANGE:
		return
	var data := ContentDB.tree(tree["type"])
	if player.skills.level("woodcutting") < data["level"]:
		sim.message(player, "You need Woodcutting %d to chop this." % data["level"], events)
		return
	var tier := tool_tier(player, "axe")
	if tier == 0:
		sim.message(player, "You need an axe you can use.", events)
		return
	if tree["felled_until"] != -1:
		sim.message(player, "Only a stump remains.", events)
		return
	player.target_id = -1
	player.skill_action = {"type": "chop", "tree": tree_id, "next_tick": sim.tick + CHOP_TICKS[tier]}
	events.append({"type": "skill_started", "id": player.id, "action": "chop", "tick": sim.tick})


func start_fishing(player: RefCounted, spot_id: int, events: Array) -> void:
	var spot: Dictionary = fishing_spots.get(spot_id, {})
	if spot.is_empty() or _distance(player.position, spot["position"]) > FISHING_RANGE:
		return
	var data := ContentDB.fishing_spot(spot["type"])
	var lowest: int = data["catches"].map(func(c): return c["level"]).min()
	if player.skills.level("fishing") < lowest:
		sim.message(player, "You need Fishing %d to fish here." % lowest, events)
		return
	if tool_tier(player, data["tool"]) == 0:
		sim.message(player, "You need a %s to fish here." % FISHING_TOOLS.get(data["tool"], data["tool"]), events)
		return
	player.target_id = -1
	player.skill_action = {"type": "fish", "spot": spot_id, "next_tick": sim.tick + FISH_TICKS}
	events.append({"type": "skill_started", "id": player.id, "action": "fish", "tick": sim.tick})


func start_craft(player: RefCounted, kind: String, recipe_id: String, count: int, events: Array) -> void:
	var recipe := ContentDB.recipe(kind, recipe_id)
	if recipe.is_empty() or not STATIONS_FOR_KIND.has(kind):
		return
	var station := {"position": null}
	var needed: Array = STATIONS_FOR_KIND[kind]
	if not needed.is_empty():
		station = _nearby_station(player.position, needed)
		if station.is_empty():
			return
	var problem := _craft_problem(player, kind, recipe)
	if not problem.is_empty():
		sim.message(player, problem, events)
		return
	player.target_id = -1
	player.skill_action = {"type": "craft", "kind": kind, "recipe": recipe_id, "remaining": maxi(count, 1),
		"station": station["position"], "next_tick": sim.tick + CRAFT_TICKS}
	events.append({"type": "skill_started", "id": player.id, "action": kind, "tick": sim.tick})


func stop(player: RefCounted, events: Array) -> void:
	if not player.skill_action.is_empty():
		player.skill_action = {}
		events.append({"type": "skill_stopped", "id": player.id, "tick": sim.tick})


# --- Per tick -----------------------------------------------------------

func process(players: Array, events: Array) -> void:
	for rock in rocks.values():
		if rock["depleted_until"] != -1 and rock["depleted_until"] <= sim.tick:
			rock["depleted_until"] = -1
			events.append({"type": "rock_respawned", "rock": rock["id"], "tick": sim.tick})
	for tree in trees.values():
		if tree["felled_until"] != -1 and tree["felled_until"] <= sim.tick:
			tree["felled_until"] = -1
			events.append({"type": "tree_regrown", "tree": tree["id"], "tick": sim.tick})
	for player in players:
		var action: Dictionary = player.skill_action
		if action.is_empty():
			continue
		if not player.is_alive():
			stop(player, events)
		elif action["type"] == "mine":
			_process_mining(player, action, events)
		elif action["type"] == "chop":
			_process_chopping(player, action, events)
		elif action["type"] == "fish":
			_process_fishing(player, action, events)
		elif action["type"] == "craft":
			_process_craft(player, action, events)


func _process_mining(player: RefCounted, action: Dictionary, events: Array) -> void:
	var rock: Dictionary = rocks[action["rock"]]
	if _distance(player.position, rock["position"]) > ACTION_RANGE or rock["depleted_until"] != -1:
		stop(player, events)
		return
	if sim.tick < action["next_tick"]:
		return
	var data := ContentDB.rock(rock["type"])
	var tier := tool_tier(player, "pickaxe")
	action["next_tick"] = sim.tick + MINE_TICKS.get(tier, 4)
	if player.inventory.space_for(data["ore"], 1) == 0:
		sim.message(player, "Your inventory is too full to hold any more ore.", events)
		stop(player, events)
		return
	if sim.rng.randf() >= mine_chance(player.skills.level("mining"), data, tier):
		return
	sim.give_item(player.id, data["ore"], 1, "skilling", events)
	sim.award_xp(player, "mining", data["xp"], events)
	rock["depleted_until"] = sim.tick + data["respawn_ticks"]
	events.append({"type": "rock_depleted", "rock": rock["id"], "tick": sim.tick})
	stop(player, events)


## Keeps chopping until the tree falls or the pack is full. Common trees
## fall after one log; hardwoods give several first.
func _process_chopping(player: RefCounted, action: Dictionary, events: Array) -> void:
	var tree: Dictionary = trees[action["tree"]]
	if _distance(player.position, tree["position"]) > ACTION_RANGE or tree["felled_until"] != -1:
		stop(player, events)
		return
	if sim.tick < action["next_tick"]:
		return
	var data := ContentDB.tree(tree["type"])
	var tier := tool_tier(player, "axe")
	action["next_tick"] = sim.tick + CHOP_TICKS.get(tier, 4)
	if player.inventory.space_for(data["log"], 1) == 0:
		sim.message(player, "Your inventory is too full to hold any more logs.", events)
		stop(player, events)
		return
	if sim.rng.randf() >= gather_chance(player.skills.level("woodcutting"), data["level"], data["difficulty"], tier):
		return
	sim.give_item(player.id, data["log"], 1, "skilling", events)
	sim.award_xp(player, "woodcutting", data["xp"], events)
	if sim.rng.randf() < data["fell_chance"]:
		tree["felled_until"] = sim.tick + data["respawn_ticks"]
		events.append({"type": "tree_felled", "tree": tree["id"], "tick": sim.tick})
		stop(player, events)


## Spots never run out. Each attempt tries the best catch the player can
## land first, then the easier ones.
func _process_fishing(player: RefCounted, action: Dictionary, events: Array) -> void:
	var spot: Dictionary = fishing_spots[action["spot"]]
	if _distance(player.position, spot["position"]) > FISHING_RANGE:
		stop(player, events)
		return
	if sim.tick < action["next_tick"]:
		return
	action["next_tick"] = sim.tick + FISH_TICKS
	var data := ContentDB.fishing_spot(spot["type"])
	var level: int = player.skills.level("fishing")
	var catches: Array = data["catches"].filter(func(c): return c["level"] <= level)
	catches.sort_custom(func(a, b): return a["level"] > b["level"])
	for catch in catches:
		if player.inventory.space_for(catch["fish"], 1) == 0:
			sim.message(player, "Your inventory is too full to hold any more fish.", events)
			stop(player, events)
			return
		if sim.rng.randf() < gather_chance(level, catch["level"], 0.0, 1, FISH_BASE_CHANCE):
			sim.give_item(player.id, catch["fish"], 1, "skilling", events)
			sim.award_xp(player, "fishing", catch["xp"], events)
			return


func _process_craft(player: RefCounted, action: Dictionary, events: Array) -> void:
	if action["station"] != null and _distance(player.position, action["station"]) > ACTION_RANGE:
		stop(player, events)
		return
	if sim.tick < action["next_tick"]:
		return
	action["next_tick"] = sim.tick + CRAFT_TICKS
	var kind: String = action["kind"]
	var recipe := ContentDB.recipe(kind, action["recipe"])
	var problem := _craft_problem(player, kind, recipe)
	if not problem.is_empty():
		sim.message(player, problem, events)
		stop(player, events)
		return
	for entry in recipe["inputs"]:
		player.inventory.remove(entry["item"], entry["quantity"])
	var skill: String = SKILL_FOR_KIND[kind]
	var level: int = player.skills.level(skill)
	if sim.rng.randf() >= recipe.get("success", 1.0):
		sim.message(player, "The ore is too impure and you lose it.", events)
		events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
	elif sim.rng.randf() < burn_chance(level, recipe):
		sim.give_item(player.id, recipe["burnt"], 1, "skilling", events)
		events.append({"type": "burnt", "id": player.id, "item": recipe["output"], "tick": sim.tick})
	else:
		sim.give_item(player.id, recipe["output"], recipe.get("quantity", 1), "skilling", events)
		sim.award_xp(player, skill, recipe["xp"], events)
	action["remaining"] -= 1
	if action["remaining"] <= 0:
		stop(player, events)


## Whether the player has learned this recipe: some are taught by a quest,
## others bought as a Slayer unlock.
static func knows_recipe(player: RefCounted, recipe: Dictionary) -> bool:
	if recipe.has("requires_quest") and not player.quests.get(recipe["requires_quest"], {}).get("done", false):
		return false
	return not recipe.has("requires_unlock") or player.slayer_unlocks.has(recipe["requires_unlock"])


## Why the player can't make this right now, or "" if they can.
func _craft_problem(player: RefCounted, kind: String, recipe: Dictionary) -> String:
	var skill: String = SKILL_FOR_KIND[kind]
	if not knows_recipe(player, recipe):
		return "You don't know how to make that yet."
	if player.skills.level(skill) < recipe["level"]:
		return "You need %s %d to make that." % [skill.capitalize(), recipe["level"]]
	if recipe.has("tool") and tool_tier(player, recipe["tool"]) == 0:
		return "You need a %s." % recipe["tool"]
	for entry in recipe["inputs"]:
		if player.inventory.count(entry["item"]) < entry["quantity"]:
			return "You don't have the materials to make that."
	return ""


func _nearby_station(position: Vector3, kinds: Array) -> Dictionary:
	for station in stations:
		if station["kind"] in kinds and _distance(position, station["position"]) <= ACTION_RANGE:
			return station
	return {}


static func _distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
