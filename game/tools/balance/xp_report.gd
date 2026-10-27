extends SceneTree
## XP-rate report: runs the real simulation for each training method for an
## hour of game time (6000 ticks of 0.6 s) at a few levels, re-issuing the
## action whenever it stops and keeping the pack supplied and emptied, like a
## diligent player. Prints a Markdown table.
##
##     godot --headless --path game --script res://tools/balance/xp_report.gd

const Simulation := preload("res://scripts/sim/simulation.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const HOUR := 6000
const NEAR := Vector3(1, 0, 0)

var _rows: Array = []


func _init() -> void:
	_gather("Mining", "mining", "copper rock", [1, 30], "bronze_pickaxe", func(sim): sim.skilling.add_rock(1, "copper_rock", NEAR), "mine", {"rock": 1}, ["copper_ore"])
	_gather("Mining", "mining", "iron rock", [15, 40, 70], "iron_pickaxe", func(sim): sim.skilling.add_rock(1, "iron_rock", NEAR), "mine", {"rock": 1}, ["iron_ore"])
	_gather("Mining", "mining", "clay", [1, 20], "bronze_pickaxe", func(sim): sim.skilling.add_rock(1, "clay_rock", NEAR), "mine", {"rock": 1}, ["clay"])
	_gather("Mining", "mining", "silver rock", [30, 50, 70], "steel_pickaxe", func(sim): sim.skilling.add_rock(1, "silver_rock", NEAR), "mine", {"rock": 1}, ["silver_ore"])
	_gather("Mining", "mining", "coal rock", [30, 50, 70], "steel_pickaxe", func(sim): sim.skilling.add_rock(1, "coal_rock", NEAR), "mine", {"rock": 1}, ["coal"])
	_gather("Mining", "mining", "gold rock", [40, 60, 80], "steel_pickaxe", func(sim): sim.skilling.add_rock(1, "gold_rock", NEAR), "mine", {"rock": 1}, ["gold_ore"])
	_gather("Woodcutting", "woodcutting", "tree", [1, 30], "bronze_axe", func(sim): sim.skilling.add_tree(1, "tree", NEAR), "chop", {"tree": 1}, ["logs"])
	_gather("Woodcutting", "woodcutting", "oak", [15, 40, 70], "iron_axe", func(sim): sim.skilling.add_tree(1, "oak_tree", NEAR), "chop", {"tree": 1}, ["oak_logs"])
	_gather("Woodcutting", "woodcutting", "pine", [30, 60, 90], "iron_axe", func(sim): sim.skilling.add_tree(1, "pine_tree", NEAR), "chop", {"tree": 1}, ["pine_logs"])
	_gather("Fishing", "fishing", "net spot", [1, 20, 40], "small_net", func(sim): sim.skilling.add_fishing_spot(1, "net_spot", NEAR), "fish", {"spot": 1}, ["raw_sardine", "raw_anchovy"])
	_gather("Fishing", "fishing", "rod spot (mackerel)", [20, 40, 70], "fishing_rod", func(sim): sim.skilling.add_fishing_spot(1, "rod_spot", NEAR), "fish", {"spot": 1}, ["raw_mackerel"])
	_gather("Fishing", "fishing", "harpoon spot (tuna)", [40, 60, 90], "harpoon", func(sim): sim.skilling.add_fishing_spot(1, "harpoon_spot", NEAR), "fish", {"spot": 1}, ["raw_tuna"])
	_make("Cooking", "cooking", "sardines (range)", [1, 34], "cook", "cooked_sardine", "range")
	_make("Cooking", "cooking", "tuna (range)", [35, 65], "cook", "cooked_tuna", "range")
	_make("Smithing", "smithing", "bronze pugio", [1, 10], "smith", "bronze_pugio", "anvil")
	_make("Smithing", "smithing", "iron gladius", [19, 40], "smith", "iron_gladius", "anvil")
	_make("Smithing", "smithing", "steel gladius", [34, 60], "smith", "steel_gladius", "anvil")
	_make("Engineering", "engineering", "oak planks (sawpit)", [20, 40], "saw", "oak_plank", "sawpit")
	_make("Fletching", "fletching", "arrow shafts", [1, 15], "fletch", "arrow_shaft", "")
	_make("Fletching", "fletching", "bronze arrows", [1, 15], "fletch", "bronze_arrow", "")
	_make("Crafting", "crafting", "leather caps", [1, 15], "leatherwork", "leather_cap", "")
	_make("Crafting", "crafting", "wolfskin jerkins", [22, 40], "leatherwork", "wolfskin_jerkin", "")
	_make("Crafting", "crafting", "throwing pots", [1, 10], "throw", "unfired_pot", "potters_wheel")
	_make("Crafting", "crafting", "firing amphorae", [12, 30], "kiln", "amphora", "kiln")
	_make("Crafting", "crafting", "glass bowls", [32, 50], "kiln", "glass_bowl", "kiln")
	_make("Medicina", "medicina", "mint tonics", [1, 20], "medicina", "mint_tonic", "")
	_make("Engineering", "engineering", "planks (sawpit)", [1, 20], "saw", "plank", "sawpit")
	_thieve("baker's stall", [1, 20], "steal", "bakers_stall", true)
	_thieve("silversmith's stall", [25, 50], "steal", "silversmiths_stall", true)
	_thieve("townsman", [1, 20], "pickpocket", "townsman", false)
	_thieve("merchant", [18, 40], "pickpocket", "merchant", false)
	_athletics([1, 40])
	_hunter("hare burrow", [1, 30], "hare_burrow")
	_hunter("fox den", [15, 45], "fox_den")
	_melee([1, 30, 60])
	print(_table())
	quit()


## A gathering method: re-issue the action whenever it stops; drop the produce.
func _gather(skill_name: String, skill: String, method: String, levels: Array, tool: String, setup: Callable, action: String, args: Dictionary, produce: Array) -> void:
	for level in levels:
		var sim := _player_sim(skill, level)
		sim.give_item(PLAYER, tool, 1, "test", [])
		_level_tool(sim, level)
		setup.call(sim)
		var xp := _hour(sim, skill, func(player: RefCounted):
			for item_id in produce:
				player.inventory.remove(item_id, player.inventory.count(item_id))
			if player.skill_action.is_empty():
				sim.queue_item_action(PLAYER, action, args))
		_rows.append([skill_name, method, level, xp])


## An artisan recipe at a station ("" for none): restock inputs, clear outputs.
func _make(skill_name: String, skill: String, method: String, levels: Array, kind: String, recipe_id: String, station: String) -> void:
	var recipe := ContentDB.recipe(kind, recipe_id)
	if recipe.is_empty():
		return
	for level in levels:
		var sim := _player_sim(skill, level)
		for tool in ["hammer", "knife", "needle", "mortar_and_pestle", "blowpipe"]:
			sim.give_item(PLAYER, tool, 1, "test", [])
		if not station.is_empty():
			sim.skilling.add_station(station, NEAR)
		var xp := _hour(sim, skill, func(player: RefCounted):
			if not player.skill_action.is_empty():
				return
			for item_id in [recipe["output"], recipe.get("burnt", "")]:
				if not item_id.is_empty():
					player.inventory.remove(item_id, player.inventory.count(item_id))
			for entry in recipe["inputs"]:
				var stackable: bool = ContentDB.item(entry["item"]).get("stackable", false)
				var wanted: int = entry["quantity"] * (20 if stackable else 1)
				if not stackable:
					wanted = entry["quantity"] * maxi(1, 24 / recipe["inputs"].size() / entry["quantity"])
				sim.give_item(PLAYER, entry["item"], maxi(wanted - player.inventory.count(entry["item"]), 0), "test", [])
			sim.queue_item_action(PLAYER, "craft", {"kind": kind, "recipe": recipe_id, "count": 28}))
		_rows.append([skill_name, method, level, xp])


func _thieve(method: String, levels: Array, action: String, target: String, stall: bool) -> void:
	for level in levels:
		# Outside the walls, so the vigiles stay out of it.
		var sim := _player_sim("thieving", level, Vector3(60, 0, 0))
		if stall:
			sim.thieving.add_stall(1, target, Vector3(61, 0, 0))
		else:
			sim.thieving.add_mark(1, target, Vector3(61, 0, 0))
		var key := "stall" if stall else "mark"
		var xp := _hour(sim, "thieving", func(player: RefCounted):
			player.hp = player.max_hp
			for item_id in ["bread", "linen", "silver_fibula", "coins"]:
				player.inventory.remove(item_id, player.inventory.count(item_id))
			sim.queue_item_action(PLAYER, action, {key: 1}))
		_rows.append(["Thieving", method, level, xp])


func _athletics(levels: Array) -> void:
	var count: int = ContentDB.course("fort_course")["obstacles"].size()
	for level in levels:
		var sim := _player_sim("athletics", level)
		for i in count:
			sim.athletics.add_obstacle(i + 1, "fort_course", i, Vector3(i * 10, 0, 0), Vector3(i * 10 + 4, 0, 0))
		var next := [0]
		var xp := _hour(sim, "athletics", func(player: RefCounted):
			player.hp = player.max_hp
			if not player.obstacle.is_empty():
				return
			# Walking between obstacles takes a couple of ticks; start the next.
			next[0] = player.course_next
			sim.set_position(PLAYER, Vector3(next[0] * 10, 0, 0))
			sim.queue_item_action(PLAYER, "obstacle", {"obstacle": next[0] + 1}))
		_rows.append(["Athletics", "training course laps", level, xp])


func _hunter(method: String, levels: Array, spot: String) -> void:
	for level in levels:
		var sim := _player_sim("hunter", level)
		sim.hunter.add_spot(1, spot, NEAR)
		sim.give_item(PLAYER, "box_trap", 1, "test", [])
		var xp := _hour(sim, "hunter", func(player: RefCounted):
			for item_id in ["raw_meat", "hare_pelt", "fox_pelt"]:
				player.inventory.remove(item_id, player.inventory.count(item_id))
			var trap: Dictionary = sim.hunter.spots[1]["trap"]
			if trap.is_empty() or trap["state"] == "caught":
				sim.queue_item_action(PLAYER, "trap", {"spot": 1}))
		_rows.append(["Hunter", method + " (one trap)", level, xp])


func _melee(levels: Array) -> void:
	for level in levels:
		var sim := _player_sim("attack", level)
		for skill in ["strength", "defence"]:
			sim.get_combatant(PLAYER).skills.xp[skill] = sim.get_combatant(PLAYER).skills.xp_for_level(level)
		var weapon := "bronze_gladius" if level < 20 else ("iron_gladius" if level < 40 else "spatha")
		sim.give_item(PLAYER, weapon, 1, "test", [])
		sim.queue_item_action(PLAYER, "equip", {"slot": 0})
		var dummy := sim.add_combatant(50)
		dummy.max_hp = 100000
		dummy.hp = 100000
		dummy.can_fight = false
		dummy.position = NEAR
		var xp := _hour(sim, "attack", func(player: RefCounted):
			dummy.hp = dummy.max_hp
			if player.target_id == -1:
				sim.queue_attack(PLAYER, 50))
		_rows.append(["Attack (accurate)", "training dummy, " + ContentDB.item(weapon)["name"].to_lower(), level, xp])


func _player_sim(skill: String, level: int, at := Vector3.ZERO) -> Simulation:
	var sim := Simulation.new(level * 31 + skill.length())
	var player: RefCounted = sim.add_player(PLAYER, at)
	player.skills.xp[skill] = player.skills.xp_for_level(level)
	player.skills.xp["cooking"] = maxf(player.skills.xp["cooking"], player.skills.xp_for_level(level if skill == "cooking" else 1))
	return sim


## Tools with level requirements (the iron axe and pickaxe) need the level.
func _level_tool(sim: Simulation, level: int) -> void:
	var player: RefCounted = sim.get_combatant(PLAYER)
	for skill in ["mining", "woodcutting"]:
		player.skills.xp[skill] = maxf(player.skills.xp[skill], player.skills.xp_for_level(mini(level, 10)))


func _hour(sim: Simulation, skill: String, each_tick: Callable) -> int:
	var player: RefCounted = sim.get_combatant(PLAYER)
	var start: float = player.skills.xp[skill]
	for i in HOUR:
		each_tick.call(player)
		sim.step()
	return roundi(player.skills.xp[skill] - start)


func _table() -> String:
	var text := "| Skill | Method | Level | XP / hour |\n|---|---|---|---|\n"
	for row in _rows:
		text += "| %s | %s | %d | %s |\n" % [row[0], row[1], row[2], _thousands(row[3])]
	return text


static func _thousands(value: int) -> String:
	var digits := str(value)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return out
