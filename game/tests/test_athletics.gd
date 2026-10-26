extends "res://tests/test_case.gd"
## Athletics: crossing obstacles, falling, and laps.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Athletics := preload("res://scripts/sim/athletics.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const COURSE := "fort_course"


func _make_sim(level := 1) -> Simulation:
	var sim := Simulation.new(8)
	sim.add_player(PLAYER)
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.skills.xp["athletics"] = player.skills.xp_for_level(level)
	var count: int = ContentDB.course(COURSE)["obstacles"].size()
	for i in count:
		sim.athletics.add_obstacle(i + 1, COURSE, i, Vector3(i * 10, 0, 0), Vector3(i * 10 + 4, 0, 0))
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _run(sim: Simulation, ticks: int) -> Array:
	var events := []
	for i in ticks:
		events.append_array(sim.step())
	return events


func _cross(sim: Simulation, index: int) -> Array:
	sim.set_position(PLAYER, Vector3(index * 10, 0, 0))
	sim.queue_item_action(PLAYER, "obstacle", {"obstacle": index + 1})
	return _run(sim, ContentDB.course(COURSE)["obstacles"][index]["ticks"] + 2)


func test_a_clean_crossing_moves_you_and_gives_xp() -> void:
	var sim := _make_sim(99)
	var events := _cross(sim, 0)
	check(events.any(func(e): return e["type"] == "obstacle_done" and e["success"]), "crossed")
	check_eq(_player(sim).position, Vector3(4, 0, 0), "at the far end")
	check_eq(_player(sim).skills.xp["athletics"] - _player(sim).skills.xp_for_level(99), 7.0, "obstacle xp")


func test_nothing_else_happens_mid_crossing() -> void:
	var sim := _make_sim(99)
	var dummy := sim.add_combatant(50)
	dummy.position = Vector3(1, 0, 0)
	sim.queue_item_action(PLAYER, "obstacle", {"obstacle": 1})
	_run(sim, 1)
	sim.queue_attack(PLAYER, 50)
	var events := _run(sim, 3)
	check(not events.any(func(e): return e["type"] == "hit" and e["attacker"] == PLAYER), "no attacking from a log")
	check_eq(_player(sim).target_id, -1, "attack ignored")


func test_low_levels_fall_sometimes_but_never_die() -> void:
	var sim := _make_sim(1)
	var falls := 0
	for attempt in 40:
		_player(sim).hp = 2
		var events := _cross(sim, 1)
		if events.any(func(e): return e["type"] == "obstacle_done" and not e["success"]):
			falls += 1
			check_eq(_player(sim).position, Vector3(10, 0, 0), "back at the start")
		check(_player(sim).hp >= 1, "a fall never kills")
	check(falls > 3, "falls happen at level 1 (%d)" % falls)


func test_falls_stop_with_level() -> void:
	var obstacle: Dictionary = ContentDB.course(COURSE)["obstacles"][1]
	check(Athletics.fail_chance(1, obstacle) > 0.0, "risky at 1")
	check_eq(Athletics.fail_chance(40, obstacle), 0.0, "safe at 40")


func test_a_lap_in_order_earns_the_bonus() -> void:
	var sim := _make_sim(99)
	var count: int = ContentDB.course(COURSE)["obstacles"].size()
	var events := []
	for i in count:
		events.append_array(_cross(sim, i))
	check(events.any(func(e): return e["type"] == "lap_complete"), "lap complete")
	check_eq(_player(sim).laps, 1, "one lap")


func test_out_of_order_is_no_lap() -> void:
	var sim := _make_sim(99)
	var events := []
	for i in [0, 2, 1, 3]:
		events.append_array(_cross(sim, i))
	check(not events.any(func(e): return e["type"] == "lap_complete"), "no lap for skipping ahead")


func test_athletics_makes_you_a_little_faster() -> void:
	check(Athletics.run_speed_bonus(99) > Athletics.run_speed_bonus(1), "faster with level")
	check(Athletics.run_speed_bonus(99) < 0.25, "but only a little")
