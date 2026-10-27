extends "res://tests/test_case.gd"
## Regulus, the basilisk king: spits venom at marked spots, petrifies the
## unwarded, and drops a crown that wards the gaze.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Slayer := preload("res://scripts/sim/slayer.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const BOSS := 50


func _make_sim(head := "", shield := "mirror_shield") -> Simulation:
	var sim := Simulation.new(4)
	var player := sim.add_player(PLAYER, Vector3.ZERO)
	for skill in ["attack", "strength", "defence", "vitality", "slayer"]:
		player.skills.xp[skill] = player.skills.xp_for_level(90)
	player.equipment.worn["head"] = head
	player.equipment.worn["shield"] = shield
	player.apply_equipment()
	player.max_hp = 500
	player.hp = 500
	player.auto_retaliate = false
	sim.add_monster(BOSS, "regulus", Vector3(1, 0, 0))
	sim.get_combatant(BOSS).target_id = PLAYER
	return sim


func test_regulus_spits_venom_at_a_marked_spot() -> void:
	var sim := _make_sim()
	var warn := {}
	var events := []
	for i in 40:
		var step := sim.step()
		events.append_array(step)
		for e in step:
			if e["type"] == "strike_warn" and warn.is_empty():
				warn = e
	check(not warn.is_empty(), "spat at least once")
	check_eq(warn.get("kind"), "venom", "venom, not a spear")
	check(events.any(func(e): return e["type"] == "message" and "spits venom" in e["text"]), "warned to move")
	check(events.any(func(e): return e["type"] == "hit" and e.get("kind") == "venom" and e["target"] == PLAYER), "the venom lands on a player who stays put")


func test_the_crown_wards_the_gaze_like_a_mirror_shield() -> void:
	var sim := _make_sim("crown_of_regulus", "")
	var player: RefCounted = sim.get_combatant(PLAYER)
	check_eq(Slayer.unwarded_effect("regulus", player.equipment), "", "the crown wards Regulus")
	check_eq(Slayer.unwarded_effect("basilisk", player.equipment), "", "and basilisks")
	var bare := _make_sim("", "")
	check_eq(Slayer.unwarded_effect("basilisk", bare.get_combatant(PLAYER).equipment), "petrify", "nothing worn, petrified")


func test_regulus_needs_slayer_50() -> void:
	check_eq(Slayer.required_level("regulus"), 50, "Slayer 50")


func test_ursa_gives_regulus_contracts() -> void:
	var tasks := Slayer.eligible_tasks(ContentDB.venator("ursa"), 85, 60).map(func(t): return t["monster"])
	check(tasks.has("regulus"), "assigned at combat 85, Slayer 60")
	tasks = Slayer.eligible_tasks(ContentDB.venator("ursa"), 79, 60).map(func(t): return t["monster"])
	check(not tasks.has("regulus"), "not below combat 80")
