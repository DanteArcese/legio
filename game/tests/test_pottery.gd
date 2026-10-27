extends "res://tests/test_case.gd"
## Pottery and glass: clay from the pond, thrown on the wheel, fired in the
## kiln; sand and a blowpipe make glass.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const Items := preload("res://scripts/sim/items.gd")

const PLAYER := 1


func _make_sim(level: int, items := {}) -> Simulation:
	var sim := Simulation.new(19)
	var player := sim.add_player(PLAYER)
	player.skills.xp["crafting"] = Skills.xp_for_level(level)
	for item_id in items:
		sim.give_item(PLAYER, item_id, items[item_id], "test", [])
	sim.skilling.add_station("potters_wheel", Vector3(1, 0, 0))
	sim.skilling.add_station("kiln", Vector3(0, 0, 1))
	return sim


func _craft(sim: Simulation, kind: String, recipe: String, count: int) -> void:
	sim.queue_item_action(PLAYER, "craft", {"kind": kind, "recipe": recipe, "count": count})
	for i in count * 6 + 4:
		sim.step()


func _count(sim: Simulation, item_id: String) -> int:
	return sim.get_combatant(PLAYER).inventory.count(item_id)


func test_clay_is_thrown_then_fired() -> void:
	var sim := _make_sim(1, {"clay": 2})
	_craft(sim, "throw", "unfired_pot", 2)
	check_eq(_count(sim, "unfired_pot"), 2, "two pots thrown")
	_craft(sim, "kiln", "clay_pot", 2)
	check_eq(_count(sim, "clay_pot"), 2, "fired")
	check(sim.get_combatant(PLAYER).skills.xp["crafting"] > 0.0, "Crafting XP")


func test_amphorae_need_crafting_12() -> void:
	var sim := _make_sim(11, {"clay": 3})
	_craft(sim, "throw", "unfired_amphora", 1)
	check_eq(_count(sim, "unfired_amphora"), 0, "too low")


func test_glass_needs_sand_and_a_blowpipe() -> void:
	var sim := _make_sim(25, {"sand": 4})
	_craft(sim, "kiln", "glass_vial", 1)
	check_eq(_count(sim, "glass_vial"), 0, "no blowpipe")
	sim.give_item(PLAYER, "blowpipe", 1, "test", [])
	_craft(sim, "kiln", "glass_vial", 2)
	check_eq(_count(sim, "glass_vial"), 2, "two vials")
	check_eq(_count(sim, "sand"), 0, "two sand each")


func test_mining_clay_and_selling_pots() -> void:
	var sim := _make_sim(1, {"bronze_pickaxe": 1})
	sim.skilling.add_rock(1, "clay_rock", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "mine", {"rock": 1})
	for i in 40:
		sim.step()
	check(_count(sim, "clay") > 0, "dug clay")
	check(Items.sell_price("gallic_merchant", "clay_pot") > Items.sell_price("gallic_merchant", "clay"), "a pot sells for more than its clay")
