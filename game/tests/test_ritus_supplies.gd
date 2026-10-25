extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")

const PLAYER := 1


func _make_sim() -> Simulation:
	var sim := Simulation.new(31)
	sim.add_player(PLAYER)
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _run(sim: Simulation, ticks: int) -> Array:
	var events := []
	for i in ticks:
		events.append_array(sim.step())
	return events


func _set_level(sim: Simulation, skill: String, level: int) -> void:
	_player(sim).skills.xp[skill] = Skills.xp_for_level(level)


func test_galena_needs_mining_10() -> void:
	var sim := _make_sim()
	sim.give_item(PLAYER, "bronze_pickaxe", 1, "test", [])
	sim.skilling.add_rock(1, "galena_rock", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "mine", {"rock": 1})
	check(sim.step().any(func(e): return e["type"] == "message" and "Mining 10" in e["text"]), "needs Mining 10")
	_set_level(sim, "mining", 10)
	sim.queue_item_action(PLAYER, "mine", {"rock": 1})
	_run(sim, 120)
	check_eq(_player(sim).inventory.count("galena"), 1, "mined galena at 10")


func test_galena_smelts_into_lead_sheets() -> void:
	var sim := _make_sim()
	_set_level(sim, "smithing", 5)
	sim.skilling.add_station("furnace", Vector3(1, 0, 0))
	sim.give_item(PLAYER, "galena", 3, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "smelt", "recipe": "lead_sheet", "count": 28})
	_run(sim, 20)
	check_eq(_player(sim).inventory.count("lead_sheet"), 3, "three sheets")


func test_one_bar_makes_fifteen_nails() -> void:
	var sim := _make_sim()
	_set_level(sim, "smithing", 3)
	sim.skilling.add_station("anvil", Vector3(1, 0, 0))
	sim.give_item(PLAYER, "hammer", 1, "test", [])
	sim.give_item(PLAYER, "bronze_bar", 2, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "smith", "recipe": "bronze_nails", "count": 28})
	_run(sim, 20)
	check_eq(_player(sim).inventory.count("bronze_nails"), 30, "15 per bar")
	check_eq(_player(sim).inventory.free_slots(), 26, "nails stack in one slot")


func test_inscribing_at_the_tomb_needs_a_stylus_and_gives_ritus_xp() -> void:
	var sim := _make_sim()
	sim.skilling.add_station("tomb", Vector3(1, 0, 0))
	sim.give_item(PLAYER, "lead_sheet", 2, "test", [])
	sim.give_item(PLAYER, "bronze_nails", 5, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "inscribe", "recipe": "binding_tablet", "count": 28})
	check(sim.step().any(func(e): return e["type"] == "message" and "stylus" in e["text"]), "needs a stylus")
	sim.give_item(PLAYER, "stylus", 1, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "inscribe", "recipe": "binding_tablet", "count": 28})
	_run(sim, 20)
	var inv: RefCounted = _player(sim).inventory
	check_eq(inv.count("binding_tablet"), 10, "five tablets per sheet")
	check_eq(inv.count("bronze_nails"), 3, "one nail per sheet")
	check_eq(inv.count("lead_sheet"), 0, "sheets used")
	check_eq(_player(sim).skills.xp["ritus"], 20.0, "ritus xp")


func test_withering_needs_ritus_15_and_grave_ash() -> void:
	var sim := _make_sim()
	sim.skilling.add_station("tomb", Vector3(1, 0, 0))
	for item in ["stylus", "lead_sheet", "bronze_nails"]:
		sim.give_item(PLAYER, item, 1, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "inscribe", "recipe": "withering_tablet", "count": 1})
	check(sim.step().any(func(e): return e["type"] == "message" and "Ritus 15" in e["text"]), "needs Ritus 15")
	_set_level(sim, "ritus", 15)
	sim.queue_item_action(PLAYER, "craft", {"kind": "inscribe", "recipe": "withering_tablet", "count": 1})
	check(sim.step().any(func(e): return e["type"] == "message" and "materials" in e["text"]), "needs grave ash")
	sim.give_item(PLAYER, "lemur_ash", 1, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "inscribe", "recipe": "withering_tablet", "count": 1})
	_run(sim, 10)
	check_eq(_player(sim).inventory.count("withering_tablet"), 5, "five withering tablets")


func test_libitinarius_sells_a_stylus_and_lead() -> void:
	var sim := _make_sim()
	sim.add_shopkeeper("libitinarius", Vector3(1, 0, 0))
	sim.give_item(PLAYER, "coins", 100, "test", [])
	sim.queue_item_action(PLAYER, "buy", {"shop": "libitinarius", "item": "stylus"})
	sim.queue_item_action(PLAYER, "buy", {"shop": "libitinarius", "item": "lead_sheet"})
	sim.step()
	check_eq(_player(sim).inventory.count("stylus"), 1, "stylus")
	check_eq(_player(sim).inventory.count("lead_sheet"), 5, "five lead sheets")
	check_eq(_player(sim).inventory.count("coins"), 25, "paid 75")


func test_shops_need_the_shopkeeper_nearby() -> void:
	var sim := _make_sim()
	sim.add_shopkeeper("libitinarius", Vector3(20, 0, 0))
	sim.give_item(PLAYER, "coins", 100, "test", [])
	sim.queue_item_action(PLAYER, "buy", {"shop": "libitinarius", "item": "stylus"})
	sim.step()
	check_eq(_player(sim).inventory.count("stylus"), 0, "too far away")


func test_ritus_counts_toward_combat_level() -> void:
	var skills := Skills.new()
	var base := skills.combat_level()
	skills.xp["ritus"] = Skills.xp_for_level(40)
	check(skills.combat_level() > base + 15, "ritus raises combat level")
