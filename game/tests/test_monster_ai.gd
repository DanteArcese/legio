extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")

const PLAYER := 1
const WOLF := 10


func _make_sim(player_position := Vector3(3, 0, 0)) -> Simulation:
	var sim := Simulation.new(4)
	var player := sim.add_combatant(PLAYER)
	player.skills = Skills.new()
	player.position = player_position
	sim.add_monster(WOLF, "wolf", Vector3.ZERO)
	return sim


func test_monster_loads_stats_from_content() -> void:
	var wolf := _make_sim().get_combatant(WOLF)
	check_eq(wolf.max_hp, 8, "hp")
	check_eq(wolf.levels["attack"], 4, "attack")
	check_eq(wolf.drop_table, "wolf", "drops")
	check(wolf.aggressive, "wolves are aggressive")


func test_aggressive_monster_targets_nearby_player() -> void:
	var sim := _make_sim()
	sim.step()
	var wolf := sim.get_combatant(WOLF)
	check_eq(wolf.target_id, PLAYER, "aggro")
	check_eq(wolf.move_target, Vector3(3, 0, 0), "chases player")


func test_no_aggro_beyond_radius() -> void:
	var sim := _make_sim(Vector3(20, 0, 0))
	sim.step()
	check_eq(sim.get_combatant(WOLF).target_id, -1, "far player ignored")


func test_no_aggro_on_high_level_players() -> void:
	var sim := _make_sim()
	var player := sim.get_combatant(PLAYER)
	for skill in ["attack", "strength", "defence"]:
		player.skills.xp[skill] = Skills.xp_for_level(30)
	sim.step()
	check_eq(sim.get_combatant(WOLF).target_id, -1, "level %d player ignored" % player.combat_level())


func test_passive_monster_only_retaliates() -> void:
	var sim := Simulation.new(4)
	var player := sim.add_combatant(PLAYER)
	player.skills = Skills.new()
	player.position = Vector3(1, 0, 0)
	player.bonuses["attack"] = 500
	var boar := sim.add_monster(WOLF, "wild_boar", Vector3.ZERO)
	sim.step()
	check_eq(boar.target_id, -1, "boar ignores player")
	sim.queue_attack(PLAYER, WOLF)
	sim.step()
	check_eq(boar.target_id, PLAYER, "boar fights back")


func test_stops_moving_when_in_reach() -> void:
	var sim := _make_sim(Vector3(1, 0, 0))
	sim.step()
	check_eq(sim.get_combatant(WOLF).move_target, null, "in reach, stands still")


func test_leash_sends_monster_home() -> void:
	var sim := _make_sim()
	sim.step()
	var wolf := sim.get_combatant(WOLF)
	sim.set_position(WOLF, Vector3(wolf.leash_radius + 1.0, 0, 0))
	sim.set_position(PLAYER, Vector3(wolf.leash_radius + 2.0, 0, 0))
	sim.step()
	check_eq(wolf.target_id, -1, "drops target")
	check(wolf.returning, "returning")
	check_eq(wolf.move_target, Vector3.ZERO, "heads to spawn")
	sim.step()
	check_eq(wolf.target_id, -1, "no re-aggro on the way home")
	sim.set_position(WOLF, Vector3(0.5, 0, 0))
	sim.step()
	check(not wolf.returning, "home again")


func test_wandering_stays_near_spawn() -> void:
	var sim := _make_sim(Vector3(50, 0, 0))
	var wolf := sim.get_combatant(WOLF)
	var moved := false
	for i in 200:
		sim.step()
		if wolf.move_target != null:
			moved = true
			check(Vector3(wolf.move_target).length() <= wolf.wander_radius + 0.001, "wander target %s" % wolf.move_target)
	check(moved, "wolf wandered at least once")


func test_killing_a_monster_drops_loot_and_it_respawns_at_spawn() -> void:
	var sim := _make_sim(Vector3(1, 0, 0))
	var wolf := sim.get_combatant(WOLF)
	wolf.hp = 1
	sim.get_combatant(PLAYER).bonuses["attack"] = 500
	sim.queue_attack(PLAYER, WOLF)
	var drop: Dictionary = {}
	for i in 30:
		for event in sim.step():
			if event["type"] == "drop":
				drop = event
		if not drop.is_empty():
			break
	check(not drop.is_empty(), "drop event")
	check_eq(drop.get("items", [{}])[0], {"item": "wolf_pelt", "quantity": 1}, "guaranteed pelt")
	sim.set_position(WOLF, Vector3(5, 0, 5))
	var respawned := false
	for i in wolf.respawn_ticks:
		respawned = respawned or sim.step().any(func(e): return e["type"] == "respawn")
	check(respawned, "respawned")
	check_eq(wolf.position, Vector3.ZERO, "back at spawn")
	check_eq(wolf.hp, wolf.max_hp, "full hp")
