extends "res://tests/test_case.gd"
## Yew: Woodcutting 60 trees and the yew longbow.

const Simulation := preload("res://scripts/sim/simulation.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1


func _make_sim(level: int) -> Simulation:
	var sim := Simulation.new(12)
	var player := sim.add_player(PLAYER)
	for skill in ["woodcutting", "fletching"]:
		player.skills.xp[skill] = player.skills.xp_for_level(level)
	sim.skilling.add_tree(1, "yew_tree", Vector3(1, 0, 0))
	sim.give_item(PLAYER, "steel_axe", 1, "test", [])
	return sim


func _run(sim: Simulation, ticks: int) -> void:
	for i in ticks:
		sim.step()


func test_yews_need_woodcutting_60() -> void:
	var sim := _make_sim(59)
	sim.queue_item_action(PLAYER, "chop", {"tree": 1})
	_run(sim, 30)
	check_eq(sim.get_combatant(PLAYER).inventory.count("yew_logs"), 0, "too low")


func test_chopping_a_yew_and_stringing_a_longbow() -> void:
	var sim := _make_sim(70)
	var player: RefCounted = sim.get_combatant(PLAYER)
	sim.queue_item_action(PLAYER, "chop", {"tree": 1})
	_run(sim, 150)
	check(player.inventory.count("yew_logs") > 0, "yew logs")
	sim.give_item(PLAYER, "bowstring", 1, "test", [])
	sim.give_item(PLAYER, "knife", 1, "test", [])
	sim.queue_item_action(PLAYER, "stop_action")
	sim.queue_item_action(PLAYER, "craft", {"kind": "fletch", "recipe": "yew_longbow", "count": 1})
	_run(sim, 8)
	check_eq(player.inventory.count("yew_longbow"), 1, "strung a longbow")
	var longbow: Dictionary = ContentDB.item("yew_longbow")["equip"]
	var composite: Dictionary = ContentDB.item("composite_bow")["equip"]
	check(longbow["bonuses"]["ranged_attack"] > composite["bonuses"]["ranged_attack"], "more accurate")
	check(longbow["range"] > composite["range"], "and longer")
