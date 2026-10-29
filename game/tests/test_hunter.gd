extends "res://tests/test_case.gd"
## Hunter: box traps at burrows and dens.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Hunter := preload("res://scripts/sim/hunter.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const SPOT := 1


func _make_sim(spot_type := "hare_burrow") -> Simulation:
	var sim := Simulation.new(12)
	sim.add_player(PLAYER)
	sim.hunter.add_spot(SPOT, spot_type, Vector3(1, 0, 0))
	sim.give_item(PLAYER, "box_trap", 1, "test", [])
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _run(sim: Simulation, ticks: int) -> Array:
	var events := []
	for i in ticks:
		events.append_array(sim.step())
	return events


func _use(sim: Simulation) -> Array:
	sim.queue_item_action(PLAYER, "trap", {"spot": SPOT})
	return _run(sim, 1)


func test_a_trap_catches_a_hare_in_time() -> void:
	var sim := _make_sim()
	_use(sim)
	check_eq(_player(sim).inventory.count("box_trap"), 0, "the trap is set")
	var events := _run(sim, 300)
	check(events.any(func(e): return e["type"] == "trap_caught"), "something walked in")
	_use(sim)
	var player := _player(sim)
	check_eq(player.inventory.count("hare_pelt"), 1, "a hare pelt")
	check_eq(player.inventory.count("raw_meat"), 1, "and meat")
	check_eq(player.inventory.count("box_trap"), 1, "the trap comes back")
	check_eq(player.skills.xp["hunter"], 32.0, "hunter xp")


func test_checking_too_early_finds_nothing() -> void:
	var sim := _make_sim()
	_use(sim)
	var events := _use(sim)
	check(events.any(func(e): return e["type"] == "message" and "Nothing yet" in e["text"]), "nothing yet")


func test_fox_dens_need_hunter_15_and_a_trap() -> void:
	var sim := _make_sim("fox_den")
	var events := _use(sim)
	check(events.any(func(e): return e["type"] == "message" and "Hunter 15" in e["text"]), "level gate")
	_player(sim).skills.xp["hunter"] = _player(sim).skills.xp_for_level(15)
	_player(sim).inventory.remove("box_trap", 1)
	events = _use(sim)
	check(events.any(func(e): return e["type"] == "message" and "box trap" in e["text"]), "needs a trap")


func test_better_hunters_catch_faster() -> void:
	var spot := ContentDB.hunt_spot("hare_burrow")
	check(Hunter.catch_chance(40, spot) > Hunter.catch_chance(1, spot), "level helps")


func test_traps_out_come_back_after_a_save() -> void:
	var sim := _make_sim()
	_use(sim)
	var data := SaveGame.from_json(SaveGame.to_json(SaveGame.capture(sim, PLAYER)))
	var loaded := Simulation.new(1)
	loaded.add_player(PLAYER)
	check(SaveGame.restore(loaded, PLAYER, data), "restored")
	check_eq(loaded.get_combatant(PLAYER).inventory.count("box_trap"), 1, "the trap is back in the pack")


func test_dormice_need_hunter_40_and_roast_with_honey() -> void:
	var sim := _make_sim("dormouse_nest")
	var player := _player(sim)
	var events := _use(sim)
	check_eq(player.inventory.count("box_trap"), 1, "Hunter 1 can't set a trap at a nest")
	player.skills.xp["hunter"] = player.skills.xp_for_level(40)
	_use(sim)
	events = _run(sim, 600)
	check(events.any(func(e): return e["type"] == "trap_caught"), "a dormouse walked in")
	_use(sim)
	check_eq(player.inventory.count("dormouse"), 1, "a dormouse")
	player.skills.xp["cooking"] = player.skills.xp_for_level(80)
	sim.skilling.add_station("range", Vector3(0, 0, 1))
	sim.give_item(PLAYER, "honey", 1, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "cook", "recipe": "honeyed_dormouse", "count": 1})
	_run(sim, 8)
	check_eq(player.inventory.count("honeyed_dormouse"), 1, "honeyed dormouse")
	check_eq(ContentDB.item("honeyed_dormouse")["heals"], 16, "heals 16")
