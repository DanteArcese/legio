extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/sim/simulation.gd")

const PLAYER := 1
const DUMMY := 2


func _make_sim(seed_value := 1) -> Simulation:
	var sim := Simulation.new(seed_value)
	var player := sim.add_combatant(PLAYER)
	player.max_hit = 3
	player.accuracy = 1.0
	player.attack_speed = 4
	var dummy := sim.add_combatant(DUMMY)
	dummy.max_hp = 1000
	dummy.hp = 1000
	dummy.max_hit = 0
	dummy.position = Vector3(1, 0, 0)
	return sim


func _hits(events: Array) -> Array:
	return events.filter(func(e): return e["type"] == "hit")


func _run(sim: Simulation, ticks: int) -> Array:
	var events := []
	for i in ticks:
		events.append_array(sim.step())
	return events


func test_commands_wait_for_next_tick() -> void:
	var sim := _make_sim()
	sim.queue_attack(PLAYER, DUMMY)
	check_eq(sim.get_combatant(PLAYER).target_id, -1, "no target before tick")
	sim.step()
	check_eq(sim.get_combatant(PLAYER).target_id, DUMMY, "target after tick")


func test_commands_between_ticks_are_all_applied_in_order() -> void:
	var sim := _make_sim()
	sim.queue_attack(PLAYER, DUMMY)
	sim.queue_stop(PLAYER)
	sim.step()
	check_eq(sim.get_combatant(PLAYER).target_id, -1, "stop after attack wins")


func test_attacks_are_spaced_by_attack_speed() -> void:
	var sim := _make_sim()
	sim.queue_attack(PLAYER, DUMMY)
	var ticks := _hits(_run(sim, 12)).map(func(e): return e["tick"])
	check_eq(ticks, [1, 5, 9], "hit ticks")


func test_no_attack_when_out_of_reach() -> void:
	var sim := _make_sim()
	sim.set_position(DUMMY, Vector3(10, 0, 0))
	sim.queue_attack(PLAYER, DUMMY)
	check_eq(_hits(_run(sim, 8)).size(), 0, "hits while far away")
	sim.set_position(DUMMY, Vector3(1, 0, 0))
	check_eq(_hits(_run(sim, 1)).size(), 1, "hits once in reach")


func test_same_seed_gives_same_results() -> void:
	var a := _make_sim(42)
	var b := _make_sim(42)
	for sim in [a, b]:
		sim.get_combatant(PLAYER).accuracy = 0.5
		sim.queue_attack(PLAYER, DUMMY)
	check_eq(_run(a, 40), _run(b, 40), "events")


func test_damage_stays_within_max_hit() -> void:
	var sim := _make_sim()
	sim.get_combatant(PLAYER).attack_speed = 1
	sim.queue_attack(PLAYER, DUMMY)
	for hit in _hits(_run(sim, 100)):
		check(hit["damage"] >= 1 and hit["damage"] <= 3, "damage %s" % hit["damage"])


func test_auto_retaliate_targets_attacker_after_delay() -> void:
	var sim := _make_sim()
	var dummy := sim.get_combatant(DUMMY)
	dummy.max_hit = 1
	dummy.accuracy = 1.0
	dummy.attack_speed = 4
	sim.queue_attack(PLAYER, DUMMY)
	var events := _run(sim, 4)
	check_eq(dummy.target_id, PLAYER, "dummy retaliates")
	var retaliation := _hits(events).filter(func(e): return e["attacker"] == DUMMY)
	check_eq(retaliation.map(func(e): return e["tick"]), [3], "retaliation tick")


func test_no_retaliation_when_disabled() -> void:
	var sim := _make_sim()
	var dummy := sim.get_combatant(DUMMY)
	dummy.max_hit = 1
	dummy.auto_retaliate = false
	sim.queue_attack(PLAYER, DUMMY)
	_run(sim, 4)
	check_eq(dummy.target_id, -1, "dummy target")


func test_death_clears_targets_and_respawns() -> void:
	var sim := _make_sim()
	var dummy := sim.get_combatant(DUMMY)
	dummy.max_hp = 1
	dummy.hp = 1
	dummy.respawn_ticks = 3
	sim.queue_attack(PLAYER, DUMMY)
	var events := sim.step()
	check(events.any(func(e): return e["type"] == "death" and e["id"] == DUMMY), "death event")
	check_eq(sim.get_combatant(PLAYER).target_id, -1, "attacker target cleared")
	var later := _run(sim, 3)
	check(later.any(func(e): return e["type"] == "respawn" and e["tick"] == 4), "respawn at tick 4")
	check_eq(dummy.hp, 1, "hp restored")


func test_cannot_target_self_or_dead() -> void:
	var sim := _make_sim()
	sim.queue_attack(PLAYER, PLAYER)
	sim.step()
	check_eq(sim.get_combatant(PLAYER).target_id, -1, "self target")
	sim.get_combatant(DUMMY).hp = 0
	sim.queue_attack(PLAYER, DUMMY)
	sim.step()
	check_eq(sim.get_combatant(PLAYER).target_id, -1, "dead target")
