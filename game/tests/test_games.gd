extends "res://tests/test_case.gd"
## The munera: waves spawned by the sim, coins per wave, the rudis for the
## last, a fall that isn't a death, and forfeiting by leaving the sands.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Games := preload("res://scripts/sim/games.gd")

const PLAYER := 1
const ARENA := Vector3(350, 0, 160)
const EDITOR := Vector3(340, 0, 180)


func _make_sim(level := 40) -> Simulation:
	var sim := Simulation.new(9)
	var player := sim.add_player(PLAYER, EDITOR)
	for skill in ["attack", "strength", "defence", "vitality"]:
		player.skills.xp[skill] = player.skills.xp_for_level(level)
	player.max_hp = level
	player.hp = level
	sim.games.set_arena(ARENA)
	sim.games.set_editor(EDITOR)
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _enter(sim: Simulation) -> Array:
	sim.queue_item_action(PLAYER, "start_games")
	var events := sim.step()
	for i in Games.data()["rest_ticks"] + 1:
		events.append_array(sim.step())
	return events


## Kills every monster of the current wave as if the player did.
func _clear_wave(sim: Simulation) -> Array:
	var events: Array[Dictionary] = []
	for id in _player(sim).games["alive"].duplicate():
		var monster: RefCounted = sim.get_combatant(id)
		monster.last_attacker_id = PLAYER
		monster.hp = 0
		sim.kill(monster, events)
	events.append_array(sim.step())
	return events


func test_entry_needs_combat_20() -> void:
	var sim := _make_sim(5)
	sim.queue_item_action(PLAYER, "start_games")
	var events := sim.step()
	check(not Games.in_games(_player(sim)), "too weak to enter")
	check(events.any(func(e): return e["type"] == "message" and "Combat 20" in e["text"]), "told why")


func test_waves_spawn_pay_and_end_with_the_rudis() -> void:
	var sim := _make_sim()
	var events := _enter(sim)
	check(Games.in_games(_player(sim)), "in the games")
	check(_player(sim).position.distance_to(ARENA) < 0.1, "out on the sand")
	var spawn: Array = events.filter(func(e): return e["type"] == "games_spawn")
	check_eq(spawn.size(), 1, "the first wave spawned")
	check_eq(spawn[0]["monsters"].size() if spawn else 0, Games.data()["waves"][0]["monsters"].size(), "with the wave's monsters")
	var first_id: int = spawn[0]["monsters"][0]["id"] if spawn else -1
	check(first_id >= Games.ID_BASE, "arena ids are reserved")
	check_eq(sim.get_combatant(first_id).target_id, PLAYER, "they come for you")
	var coins_before: int = _player(sim).inventory.count("coins")
	var waves: Array = Games.data()["waves"]
	for i in waves.size():
		events = _clear_wave(sim)
		check(events.any(func(e): return e["type"] == "games_despawn"), "wave %d's bodies taken away" % (i + 1))
		if i < waves.size() - 1:
			for t in Games.data()["rest_ticks"] + 1:
				sim.step()
	check(not Games.in_games(_player(sim)), "the games are over")
	check_eq(_player(sim).inventory.count("rudis"), 1, "the rudis")
	var paid: int = waves.reduce(func(total, w): return total + w["coins"], 0)
	check_eq(_player(sim).inventory.count("coins") - coins_before, paid, "paid for every wave")
	check(sim.get_combatant(first_id) == null, "no arena monsters left behind")


func test_a_fall_in_the_arena_is_not_a_death() -> void:
	var sim := _make_sim()
	_enter(sim)
	var coins: int = _player(sim).inventory.count("coins")
	var events: Array[Dictionary] = []
	_player(sim).hp = 0
	sim.kill(_player(sim), events)
	check(not Games.in_games(_player(sim)), "carried out")
	check_eq(_player(sim).hp, _player(sim).max_hp, "patched up")
	check(not events.any(func(e): return e["type"] == "death"), "no death")
	check(sim.grave_of(PLAYER).is_empty(), "no grave")
	check_eq(_player(sim).inventory.count("coins"), coins, "keeps everything")


func test_leaving_the_sands_forfeits() -> void:
	var sim := _make_sim()
	_enter(sim)
	_player(sim).position = ARENA + Vector3(40, 0, 0)
	var events := sim.step()
	check(not Games.in_games(_player(sim)), "forfeited")
	check(events.any(func(e): return e["type"] == "games_despawn"), "the wave is taken away")
