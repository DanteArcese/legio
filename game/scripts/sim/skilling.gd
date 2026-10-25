extends RefCounted
## Gathering and artisan actions: mining rocks, and making things at
## stations (smelting at a furnace, smithing at an anvil, cooking at a
## range). Actions repeat on ticks, OSRS-style, until done or interrupted.

const ContentDB := preload("res://scripts/content/content_db.gd")

## How close a player must stay to the rock or station.
const ACTION_RANGE := 2.2
## Ticks between mining attempts, by pickaxe tier.
const MINE_TICKS := {1: 4, 2: 3}
const CRAFT_TICKS := 4
## Our own mining formula: chance per attempt.
const MINE_BASE_CHANCE := 0.35
const MINE_CHANCE_PER_LEVEL := 0.015
const MINE_CHANCE_PER_TIER := 0.1
## Burn chance at the recipe's level, falling to 0 at its stop_burning level.
const MAX_BURN_CHANCE := 0.5
const STATION_FOR_KIND := {"smelt": "furnace", "smith": "anvil", "cook": "range"}
const SKILL_FOR_KIND := {"smelt": "smithing", "smith": "smithing", "cook": "cooking"}

var sim: RefCounted
## rock id -> {"id", "type", "position", "depleted_until"}
var rocks := {}
## [{"kind": "furnace" | "anvil" | "range", "position": Vector3}]
var stations: Array[Dictionary] = []


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


func add_rock(id: int, rock_type: String, position: Vector3) -> void:
	rocks[id] = {"id": id, "type": rock_type, "position": position, "depleted_until": -1}


func add_station(kind: String, position: Vector3) -> void:
	stations.append({"kind": kind, "position": position})


static func mine_chance(level: int, rock: Dictionary, tool_tier: int) -> float:
	var chance: float = MINE_BASE_CHANCE + MINE_CHANCE_PER_LEVEL * (level - rock["level"]) \
		+ MINE_CHANCE_PER_TIER * (tool_tier - 1) - rock["difficulty"]
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


func start_craft(player: RefCounted, kind: String, recipe_id: String, count: int, events: Array) -> void:
	var recipe := ContentDB.recipe(kind, recipe_id)
	if recipe.is_empty():
		return
	var station := _nearby_station(player.position, STATION_FOR_KIND[kind])
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
	for player in players:
		var action: Dictionary = player.skill_action
		if action.is_empty():
			continue
		if not player.is_alive():
			stop(player, events)
		elif action["type"] == "mine":
			_process_mining(player, action, events)
		else:
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


func _process_craft(player: RefCounted, action: Dictionary, events: Array) -> void:
	if _distance(player.position, action["station"]) > ACTION_RANGE:
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
		sim.give_item(player.id, recipe["output"], 1, "skilling", events)
		sim.award_xp(player, skill, recipe["xp"], events)
	action["remaining"] -= 1
	if action["remaining"] <= 0:
		stop(player, events)


## Why the player can't make this right now, or "" if they can.
func _craft_problem(player: RefCounted, kind: String, recipe: Dictionary) -> String:
	var skill: String = SKILL_FOR_KIND[kind]
	if player.skills.level(skill) < recipe["level"]:
		return "You need %s %d to make that." % [skill.capitalize(), recipe["level"]]
	if recipe.has("tool") and tool_tier(player, recipe["tool"]) == 0:
		return "You need a %s." % recipe["tool"]
	for entry in recipe["inputs"]:
		if player.inventory.count(entry["item"]) < entry["quantity"]:
			return "You don't have the materials to make that."
	return ""


func _nearby_station(position: Vector3, kind: String) -> Dictionary:
	for station in stations:
		if station["kind"] == kind and _distance(position, station["position"]) <= ACTION_RANGE:
			return station
	return {}


static func _distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
