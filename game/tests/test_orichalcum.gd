extends "res://tests/test_case.gd"
## Orichalcum: veins in the Vipasca pit, bars from orichalcum ore and four
## coal, and the orichalcum tier of gear and tools.

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


func test_an_orichalcum_bar_takes_four_coal() -> void:
	var sim := _make_sim(50, {"orichalcum_ore": 1, "coal": 4})
	sim.queue_item_action(PLAYER, "craft", {"kind": "smelt", "recipe": "orichalcum_bar", "count": 1})
	_run(sim, 10)
	check_eq(_count(sim, "orichalcum_bar"), 1, "smelted a bar")
	check_eq(_count(sim, "coal"), 0, "four coal used")


func test_orichalcum_gear_beats_steel() -> void:
	var sim := _make_sim(60, {"orichalcum_bar": 3, "hammer": 1})
	sim.queue_item_action(PLAYER, "craft", {"kind": "smith", "recipe": "orichalcum_lorica", "count": 1})
	_run(sim, 10)
	check_eq(_count(sim, "orichalcum_lorica"), 1, "smithed a lorica")
	for piece in ["gladius", "pugio"]:
		var o: Dictionary = ContentDB.item("orichalcum_" + piece)["equip"]["bonuses"]
		var s: Dictionary = ContentDB.item("steel_" + piece)["equip"]["bonuses"]
		check(o["attack"] > s["attack"] and o["strength"] > s["strength"], "orichalcum %s beats steel" % piece)
	for piece in ["galea", "scutum", "lorica"]:
		var o: int = ContentDB.item("orichalcum_" + piece)["equip"]["bonuses"]["defence"]
		var s: int = ContentDB.item("steel_" + piece)["equip"]["bonuses"]["defence"]
		check(o > s, "orichalcum %s defends better (%d > %d)" % [piece, o, s])


func test_orichalcum_tools_are_tier_four_and_mine_veins() -> void:
	var sim := _make_sim(60, {"orichalcum_pickaxe": 1, "orichalcum_axe": 1})
	var player: RefCounted = sim.get_combatant(PLAYER)
	check_eq(Skilling.tool_tier(player, "pickaxe"), 4, "pickaxe")
	check_eq(Skilling.tool_tier(player, "axe"), 4, "axe")
	sim.skilling.add_rock(1, "orichalcum_rock", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "mine", {"rock": 1})
	_run(sim, 80)
	check(_count(sim, "orichalcum_ore") > 0, "mined orichalcum")
