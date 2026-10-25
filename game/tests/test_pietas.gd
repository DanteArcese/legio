extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")

const PLAYER := 1


func _make_sim(level := 30) -> Simulation:
	var sim := Simulation.new(3)
	var player := sim.add_player(PLAYER)
	player.skills.xp["pietas"] = Skills.xp_for_level(level)
	player.favour = float(level)
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _act(sim: Simulation, action: String, args := {}) -> Array:
	sim.queue_item_action(PLAYER, action, args)
	return sim.step()


func _run(sim: Simulation, ticks: int) -> Array:
	var events := []
	for i in ticks:
		events.append_array(sim.step())
	return events


func test_blessing_raises_effective_level() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	player.skills.xp["strength"] = Skills.xp_for_level(40)
	var before: int = player.effective_level("strength")
	_act(sim, "bless", {"blessing": "mars_fury"})
	check_eq(player.blessings, ["mars_fury"], "active")
	check_eq(player.effective_level("strength"), before + 4, "+10% of 40")


func test_blessings_need_the_level() -> void:
	var sim := _make_sim(5)
	var events := _act(sim, "bless", {"blessing": "mars_fury"})
	check(_player(sim).blessings.is_empty(), "not at Pietas 5")
	check(events.any(func(e): return e["type"] == "message" and "Pietas 16" in e["text"]), "told why")


func test_same_aspect_replaces_and_toggle_turns_off() -> void:
	var sim := _make_sim()
	_act(sim, "bless", {"blessing": "mars_vigour"})
	_act(sim, "bless", {"blessing": "minerva_aegis"})
	_act(sim, "bless", {"blessing": "mars_fury"})
	check_eq(_player(sim).blessings, ["minerva_aegis", "mars_fury"], "fury replaced vigour")
	_act(sim, "bless", {"blessing": "minerva_aegis"})
	check_eq(_player(sim).blessings, ["mars_fury"], "toggled off")


func test_favour_drains_and_blessings_fade_when_spent() -> void:
	var sim := _make_sim(10)
	var player := _player(sim)
	player.favour = 2.0
	_act(sim, "bless", {"blessing": "mars_vigour"})
	var events := _run(sim, 30)
	check_eq(player.favour, 0.0, "spent")
	check(player.blessings.is_empty() and player.blessing_boosts.is_empty(), "faded")
	check(events.any(func(e): return e["type"] == "message" and "spent" in e["text"]), "told")


func test_praying_at_an_altar_restores_favour() -> void:
	var sim := _make_sim(12)
	sim.pietas.add_altar("heavenly", Vector3(1, 0, 0))
	_player(sim).favour = 1.0
	_act(sim, "pray")
	check_eq(_player(sim).favour, 12.0, "full")
	_player(sim).favour = 1.0
	sim.set_position(PLAYER, Vector3(10, 0, 0))
	_act(sim, "pray")
	check_eq(_player(sim).favour, 1.0, "too far away")


func test_offerings_give_xp_and_wrong_altar_halves_it() -> void:
	var sim := _make_sim(1)
	sim.pietas.add_altar("heavenly", Vector3(1, 0, 0))
	sim.give_item(PLAYER, "bones", 3, "test", [])
	_act(sim, "offer", {"item": "bones"})
	_run(sim, 12)
	check_eq(_player(sim).inventory.count("bones"), 0, "all offered")
	check_eq(_player(sim).skills.xp["pietas"], 15.0, "5 xp each")
	sim.give_item(PLAYER, "lemur_ash", 1, "test", [])
	_act(sim, "offer", {"item": "lemur_ash"})
	_run(sim, 5)
	check_eq(_player(sim).skills.xp["pietas"], 25.0, "ash at the heavenly altar: half of 20")


func test_mercury_boosts_run_speed() -> void:
	var sim := _make_sim()
	_act(sim, "bless", {"blessing": "mercury_stride"})
	check(is_equal_approx(_player(sim).blessing_boosts.get("run_speed", 0.0), 0.15), "+15% run speed")


func test_death_ends_blessings() -> void:
	var sim := _make_sim()
	_act(sim, "bless", {"blessing": "mars_vigour"})
	_player(sim).hp = 0
	sim.step()
	check(_player(sim).blessings.is_empty(), "no blessings after death")


func test_levelling_up_adds_a_point_of_favour() -> void:
	var sim := _make_sim(1)
	sim.pietas.add_altar("heavenly", Vector3(1, 0, 0))
	sim.give_item(PLAYER, "wine", 5, "test", [])
	_act(sim, "offer", {"item": "wine"})
	_run(sim, 20)
	check(_player(sim).skills.level("pietas") >= 2, "levelled up")
	check_eq(_player(sim).favour, float(_player(sim).skills.level("pietas")), "favour grew with the level")
