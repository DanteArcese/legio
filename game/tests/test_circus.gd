extends "res://tests/test_case.gd"
## Chariot racing: the track's geometry, entering, laps that must go all
## the way round, and placing against the rivals.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Circus := preload("res://scripts/sim/circus.gd")

const PLAYER := 1
const CENTER := Vector3(100, 0, 50)


func _make_sim(level := 20) -> Simulation:
	var sim := Simulation.new(5)
	sim.add_player(PLAYER)
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.skills.xp["athletics"] = player.skills.xp_for_level(level)
	sim.give_item(PLAYER, "coins", 100, "test", [])
	sim.circus.set_track(CENTER, 30.0, 12.0)
	sim.circus.set_agent(CENTER + Vector3(0, 0, 20))
	player.position = CENTER + Vector3(0, 0, 20)
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _start(sim: Simulation) -> Array:
	sim.queue_item_action(PLAYER, "start_race")
	var events := sim.step()
	for i in Circus.data()["countdown_ticks"]:
		events.append_array(sim.step())
	return events


## Drives round the racing line, a step of `per_tick` metres each tick.
func _drive(sim: Simulation, metres: float, per_tick: float) -> Array:
	var events := []
	var track: Dictionary = sim.circus.tracks["castra"]
	var s := Circus.progress(track, _player(sim).position)
	var driven := 0.0
	while driven < metres and Circus.is_racing(_player(sim)):
		driven += per_tick
		_player(sim).position = Circus.point_at(track, s + driven)
		events.append_array(sim.step())
	return events


func test_progress_and_points_agree_all_round() -> void:
	var sim := _make_sim()
	var track: Dictionary = sim.circus.tracks["castra"]
	var length := Circus.lap_length(track)
	check(is_equal_approx(length, 120.0 + TAU * 12.0), "lap length")
	for s in [0.0, 10.0, 29.0, 40.0, 67.0, 80.0, 120.0, 150.0, 170.0, length - 1.0]:
		var back := Circus.progress(track, Circus.point_at(track, s))
		check(absf(back - s) < 0.01, "round trip at %.0f (got %.2f)" % [s, back])
	check(absf(Circus.progress(track, Circus.point_at(track, 50.0, 2.0)) - 50.0) < 0.01, "outer lanes keep progress")


func test_entry_needs_athletics_and_the_fee() -> void:
	var sim := _make_sim(10)
	var events := _start(sim)
	check(events.any(func(e): return e["type"] == "message" and "Athletics 20" in e["text"]), "level check")
	check(not Circus.is_racing(_player(sim)), "not racing")
	sim = _make_sim()
	_player(sim).inventory.remove("coins", 100)
	_start(sim)
	check(not Circus.is_racing(_player(sim)), "no fee, no race")


func test_a_fast_driver_wins_the_palm() -> void:
	var sim := _make_sim()
	var events := _start(sim)
	check(Circus.is_racing(_player(sim)), "racing")
	check_eq(_player(sim).inventory.count("coins"), 75, "fee paid")
	check(events.any(func(e): return e["type"] == "race_started"), "started")
	var length := Circus.lap_length(sim.circus.tracks["castra"])
	events = _drive(sim, length * 3.0 + 5.0, 9.0)
	check(not Circus.is_racing(_player(sim)), "race over")
	var finished := events.filter(func(e): return e["type"] == "race_finished")
	check_eq(finished.size(), 1, "finished once")
	check_eq(finished[0]["place"] if finished else 0, 1, "first place")
	check_eq(_player(sim).inventory.count("victors_palm"), 1, "a victor's palm")
	check_eq(_player(sim).inventory.count("coins"), 75 + 250, "prize money")
	check(_player(sim).skills.xp["athletics"] > _player(sim).skills.xp_for_level(20) + 400, "lap and placing xp")


func test_a_slow_driver_comes_last() -> void:
	var sim := _make_sim()
	_start(sim)
	var length := Circus.lap_length(sim.circus.tracks["castra"])
	var events := _drive(sim, length * 3.0 + 5.0, 3.0)
	var finished := events.filter(func(e): return e["type"] == "race_finished")
	check_eq(finished[0]["place"] if finished else 0, 3, "third behind both rivals")
	check_eq(_player(sim).inventory.count("victors_palm"), 0, "no palm")


func test_cutting_across_does_not_count_a_lap() -> void:
	var sim := _make_sim()
	_start(sim)
	var track: Dictionary = sim.circus.tracks["castra"]
	var length := Circus.lap_length(track)
	# Jump from the start to the far straight and straight back.
	_player(sim).position = Circus.point_at(track, length * 0.6)
	sim.step()
	_player(sim).position = Circus.point_at(track, 1.0)
	sim.step()
	check_eq(_player(sim).race["lap"], 0, "no lap for a shortcut")


func test_the_live_place_tracks_the_rivals() -> void:
	var sim := _make_sim()
	_start(sim)
	_drive(sim, 60.0, 9.6)
	check_eq(sim.circus.live_place(_player(sim)), 1, "ahead after a fast start")
	for i in 20:
		sim.step()
	check_eq(sim.circus.live_place(_player(sim)), 3, "both rivals pass a stopped chariot")


func test_leaving_the_track_abandons_the_race() -> void:
	var sim := _make_sim()
	var events := _start(sim)
	_player(sim).position = CENTER + Vector3(0, 0, 60)
	events = sim.step()
	check(not Circus.is_racing(_player(sim)), "abandoned")
	check(events.any(func(e): return e["type"] == "race_ended"), "ended")


## The Circus Maximus: its own track and agent, four rivals, a quadriga's
## rules, and a laurel crown for the season's champion.
func _maximus_sim() -> Simulation:
	var sim := Simulation.new(5)
	sim.add_player(PLAYER)
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.skills.xp["athletics"] = player.skills.xp_for_level(99)
	sim.give_item(PLAYER, "coins", 5000, "test", [])
	sim.circus.set_track(CENTER, 30.0, 12.0)
	sim.circus.set_agent(CENTER + Vector3(0, 0, 20))
	var rome := Vector3(-536, 0, 31)
	sim.circus.set_track(rome, 20.0, 10.0, "maximus")
	sim.circus.set_agent(rome + Vector3(-20, 0, -18), "maximus")
	player.position = rome + Vector3(-20, 0, -18)
	return sim


func test_the_maximus_is_its_own_race() -> void:
	var sim := _maximus_sim()
	var player: RefCounted = _player(sim)
	player.skills.xp["athletics"] = player.skills.xp_for_level(49)
	sim.queue_item_action(PLAYER, "start_race")
	sim.step()
	check(player.race.is_empty(), "Athletics 50 to drive in Rome")
	player.skills.xp["athletics"] = player.skills.xp_for_level(50)
	sim.queue_item_action(PLAYER, "start_race")
	sim.step()
	check_eq(player.race.get("circus", ""), "maximus", "racing at the Maximus")
	check_eq(player.race["finishes"].size(), 4, "against four rivals")
	check_eq(player.inventory.count("coins"), 5000 - Circus.data("maximus")["fee"], "the Maximus's fee")
	check(player.position.distance_to(Vector3(-536, 0, 31)) < 35.0, "on the Roman track")


func test_a_champion_every_five_wins() -> void:
	var sim := _maximus_sim()
	var player: RefCounted = _player(sim)
	for win in 5:
		player.race = {"circus": "maximus", "start": 0, "lap": 0, "sector": 0, "finishes": [sim.tick + 1000, sim.tick + 1000, sim.tick + 1000, sim.tick + 1000]}
		sim.circus._finish(player, [])
		check_eq(player.inventory.count("laurel_crown"), 1 if win == 4 else 0, "crown after win %d" % (win + 1))
	check_eq(player.circus_wins["maximus"], 5, "five wins counted")
	check_eq(player.inventory.count("victors_palm"), 5, "a palm for each")
