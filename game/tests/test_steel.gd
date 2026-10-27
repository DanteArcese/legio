extends "res://tests/test_case.gd"
## Noric steel: coal from Vipasca, steel bars from iron ore and coal, and
## the steel tier of gear and tools.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skilling := preload("res://scripts/sim/skilling.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1


func _make_sim(level: int, items := {}) -> Simulation:
	var sim := Simulation.new(8)
	var player := sim.add_player(PLAYER)
	for skill in ["smithing", "mining", "woodcutting"]:
		player.skills.xp[skill] = Skills.xp_for_level(level)
	for item_id in items:
		sim.give_item(PLAYER, item_id, items[item_id], "test", [])
	sim.skilling.add_station("furnace", Vector3(1, 0, 0))
	sim.skilling.add_station("anvil", Vector3(0, 0, 1))
	return sim


func _run(sim: Simulation, ticks: int) -> void:
	for i in ticks:
		sim.step()


func _count(sim: Simulation, item_id: String) -> int:
	return sim.get_combatant(PLAYER).inventory.count(item_id)


func test_a_steel_bar_takes_iron_ore_and_two_coal() -> void:
	var sim := _make_sim(30, {"iron_ore": 2, "coal": 3})
	sim.queue_item_action(PLAYER, "craft", {"kind": "smelt", "recipe": "steel_bar", "count": 2})
	_run(sim, 20)
	check_eq(_count(sim, "steel_bar"), 1, "one bar: the coal ran out")
	check_eq(_count(sim, "coal"), 1, "two coal used")
	check_eq(_count(sim, "iron_ore"), 1, "one ore left")


func test_steel_needs_smithing_30() -> void:
	var sim := _make_sim(29, {"iron_ore": 1, "coal": 2})
	sim.queue_item_action(PLAYER, "craft", {"kind": "smelt", "recipe": "steel_bar", "count": 1})
	_run(sim, 10)
	check_eq(_count(sim, "steel_bar"), 0, "too low")


func test_steel_gear_is_smithed_and_beats_iron() -> void:
	var sim := _make_sim(40, {"steel_bar": 3, "hammer": 1})
	sim.queue_item_action(PLAYER, "craft", {"kind": "smith", "recipe": "steel_gladius", "count": 1})
	_run(sim, 10)
	check_eq(_count(sim, "steel_gladius"), 1, "smithed a gladius")
	var steel: Dictionary = ContentDB.item("steel_gladius")["equip"]["bonuses"]
	var iron: Dictionary = ContentDB.item("iron_gladius")["equip"]["bonuses"]
	check(steel["attack"] > iron["attack"] and steel["strength"] > iron["strength"], "steel beats iron")
	for piece in ["galea", "scutum", "lorica"]:
		var s: int = ContentDB.item("steel_" + piece)["equip"]["bonuses"]["defence"]
		var i: int = ContentDB.item("iron_" + piece)["equip"]["bonuses"]["defence"]
		check(s > i, "steel %s defends better (%d > %d)" % [piece, s, i])


func test_steel_tools_are_tier_three() -> void:
	var sim := _make_sim(30, {"steel_pickaxe": 1, "steel_axe": 1})
	var player: RefCounted = sim.get_combatant(PLAYER)
	check_eq(Skilling.tool_tier(player, "pickaxe"), 3, "pickaxe")
	check_eq(Skilling.tool_tier(player, "axe"), 3, "axe")
	check(Skilling.mine_chance(30, ContentDB.rock("coal_rock"), 3) > Skilling.mine_chance(30, ContentDB.rock("coal_rock"), 2), "lands more often than iron")


func test_mining_coal_with_a_steel_pickaxe() -> void:
	var sim := _make_sim(50, {"steel_pickaxe": 1})
	sim.skilling.add_rock(1, "coal_rock", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "mine", {"rock": 1})
	_run(sim, 60)
	check(_count(sim, "coal") > 0, "mined coal")


func test_silver_bars_make_fibulae() -> void:
	var sim := _make_sim(32, {"silver_bar": 1, "hammer": 1})
	sim.queue_item_action(PLAYER, "craft", {"kind": "smith", "recipe": "silver_fibula", "count": 1})
	_run(sim, 10)
	check_eq(_count(sim, "silver_fibula"), 1, "a fibula")
