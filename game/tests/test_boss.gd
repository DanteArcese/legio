extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/sim/simulation.gd")

const PLAYER := 1
const BOSS := 50


## A player toe to toe with Hrodgar, tough enough to survive a while.
func _make_sim() -> Simulation:
	var sim := Simulation.new(3)
	var player := sim.add_player(PLAYER, Vector3.ZERO)
	for skill in ["defence", "vitality"]:
		player.skills.xp[skill] = player.skills.xp_for_level(90)
	player.max_hp = 500
	player.hp = 500
	player.auto_retaliate = false
	sim.add_monster(BOSS, "hrodgar", Vector3(1, 0, 0))
	sim.get_combatant(BOSS).target_id = PLAYER
	return sim


func _run_until(sim: Simulation, type: String, limit := 60) -> Dictionary:
	for i in limit:
		for event in sim.step():
			if event["type"] == type:
				return event
	return {}


func test_every_fourth_attack_is_a_marked_throw() -> void:
	var sim := _make_sim()
	var warn := _run_until(sim, "strike_warn")
	check(not warn.is_empty(), "a throw is marked")
	check_eq(sim.boss.strikes.size(), 1, "one spear in the air")
	sim.step()
	check(sim.boss.strikes.size() == 1, "still in the air after a tick")
	var landed := _run_until(sim, "strike_land", 3)
	check(not landed.is_empty(), "it lands")
	check_eq(landed["tick"], warn["lands_at"], "on time")


func test_standing_in_the_mark_hurts() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	_run_until(sim, "strike_warn")
	var before: int = player.hp
	var spec: Dictionary = sim.boss.data("hrodgar")
	# Hold the boss's normal attacks off, so only the spear can land.
	sim.get_combatant(BOSS).next_attack_tick = sim.tick + 100
	_run_until(sim, "strike_land", 3)
	check(before - player.hp >= spec["throw_damage"][0], "the spear hit (%d damage)" % (before - player.hp))


func test_stepping_out_of_the_mark_dodges() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	_run_until(sim, "strike_warn")
	sim.get_combatant(BOSS).next_attack_tick = sim.tick + 100
	sim.set_position(PLAYER, Vector3(-3, 0, 0))
	var before: int = player.hp
	_run_until(sim, "strike_land", 3)
	check_eq(player.hp, before, "no damage")


func test_enrages_when_low() -> void:
	var sim := _make_sim()
	var hrodgar: RefCounted = sim.get_combatant(BOSS)
	hrodgar.hp = 20
	var enrage := _run_until(sim, "enrage", 2)
	check(not enrage.is_empty(), "enrages")
	check_eq(hrodgar.attack_speed, 3, "attacks faster")
	hrodgar.hp = hrodgar.max_hp
	sim.step()
	check_eq(hrodgar.attack_speed, 5, "calms down at full health")


func test_throws_die_with_the_boss() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	_run_until(sim, "strike_warn")
	var events: Array[Dictionary] = []
	sim.kill(sim.get_combatant(BOSS), events)
	check(sim.boss.strikes.is_empty(), "no spear left in the air")
	var before: int = player.hp
	sim.step()
	sim.step()
	check_eq(player.hp, before, "nothing lands")
