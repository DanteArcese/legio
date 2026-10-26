extends "res://tests/test_case.gd"
## Crafting: tanning hides at the rack, and sewing leather armour anywhere.

const Simulation := preload("res://scripts/sim/simulation.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")
const Equipment := preload("res://scripts/sim/equipment.gd")

const PLAYER := 1


func _make_sim(items := {}) -> Simulation:
	var sim := Simulation.new(4)
	sim.add_player(PLAYER)
	for item_id in items:
		sim.give_item(PLAYER, item_id, items[item_id], "test", [])
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _run(sim: Simulation, ticks: int) -> void:
	for i in ticks:
		sim.step()


func test_boars_always_drop_a_hide() -> void:
	var always: Array = ContentDB.drop_table("wild_boar")["always"]
	check(always.any(func(entry): return entry["item"] == "boar_hide"), "hide in the boar's always-drops")


func test_hides_are_tanned_at_the_rack() -> void:
	var sim := _make_sim({"boar_hide": 3})
	sim.queue_item_action(PLAYER, "craft", {"kind": "tan", "recipe": "leather", "count": 3})
	_run(sim, 20)
	check_eq(_player(sim).inventory.count("leather"), 0, "no rack, no leather")
	sim.skilling.add_station("tanning_rack", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "craft", {"kind": "tan", "recipe": "leather", "count": 3})
	_run(sim, 20)
	check_eq(_player(sim).inventory.count("leather"), 3, "three hides tanned")
	check_eq(_player(sim).skills.xp["crafting"], 15.0, "crafting xp")


func test_sewing_needs_a_needle_but_no_station() -> void:
	var sim := _make_sim({"leather": 1, "thread": 5})
	sim.queue_item_action(PLAYER, "craft", {"kind": "leatherwork", "recipe": "leather_cap", "count": 1})
	_run(sim, 8)
	check_eq(_player(sim).inventory.count("leather_cap"), 0, "no needle")
	sim.give_item(PLAYER, "needle", 1, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "leatherwork", "recipe": "leather_cap", "count": 1})
	_run(sim, 8)
	check_eq(_player(sim).inventory.count("leather_cap"), 1, "sewn a cap")
	check_eq(_player(sim).inventory.count("thread"), 4, "used one thread")


func test_wolfskin_needs_level_and_pelts() -> void:
	var sim := _make_sim({"needle": 1, "leather": 3, "thread": 5, "wolf_pelt": 3})
	sim.queue_item_action(PLAYER, "craft", {"kind": "leatherwork", "recipe": "wolfskin_jerkin", "count": 1})
	_run(sim, 8)
	check_eq(_player(sim).inventory.count("wolfskin_jerkin"), 0, "needs Crafting 22")
	_player(sim).skills.xp["crafting"] = _player(sim).skills.xp_for_level(22)
	sim.queue_item_action(PLAYER, "craft", {"kind": "leatherwork", "recipe": "wolfskin_jerkin", "count": 1})
	_run(sim, 8)
	check_eq(_player(sim).inventory.count("wolfskin_jerkin"), 1, "sewn at 22")
	check_eq(_player(sim).inventory.count("wolf_pelt"), 0, "pelts used")


func test_leather_suits_rangers() -> void:
	for item_id in ["leather_cap", "leather_jerkin", "wolfskin_hood", "wolfskin_jerkin"]:
		var bonuses: Dictionary = ContentDB.item(item_id)["equip"]["bonuses"]
		check(bonuses.get("ranged_attack", 0) > 0, "%s helps aim" % item_id)
		check(bonuses.get("ranged_defence", 0) > bonuses.get("defence", 0), "%s is better against arrows than blades" % item_id)
