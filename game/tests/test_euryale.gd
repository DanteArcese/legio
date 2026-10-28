extends "res://tests/test_case.gd"
## Euryale, the gorgon queen: only the Aegis (or her gorgoneion) wards her
## gaze; she throws venom at marked spots; Ursa assigns her.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Slayer := preload("res://scripts/sim/slayer.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const BOSS := 50


func _make_sim(neck := "", shield := "aegis") -> Simulation:
	var sim := Simulation.new(6)
	var player := sim.add_player(PLAYER, Vector3.ZERO)
	for skill in ["attack", "strength", "defence", "vitality", "slayer"]:
		player.skills.xp[skill] = player.skills.xp_for_level(95)
	player.equipment.worn["neck"] = neck
	player.equipment.worn["shield"] = shield
	player.apply_equipment()
	player.max_hp = 500
	player.hp = 500
	player.auto_retaliate = false
	sim.add_monster(BOSS, "euryale", Vector3(1, 0, 0))
	sim.get_combatant(BOSS).target_id = PLAYER
	return sim


func test_a_mirror_shield_does_not_fool_the_queen() -> void:
	var mirror := _make_sim("", "mirror_shield")
	check_eq(Slayer.unwarded_effect("euryale", mirror.get_combatant(PLAYER).equipment), "gorgon_gaze", "a mirror shield isn't enough")
	check_eq(Slayer.unwarded_effect("gorgon", mirror.get_combatant(PLAYER).equipment), "", "though it wards her sisters")
	var aegis := _make_sim()
	check_eq(Slayer.unwarded_effect("euryale", aegis.get_combatant(PLAYER).equipment), "", "the Aegis wards her")
	var amulet := _make_sim("gorgoneion", "")
	check_eq(Slayer.unwarded_effect("euryale", amulet.get_combatant(PLAYER).equipment), "", "so does her gorgoneion")


func test_euryale_throws_venom() -> void:
	var sim := _make_sim()
	var warned := false
	for i in 40:
		for e in sim.step():
			if e["type"] == "strike_warn" and e.get("kind") == "venom":
				warned = true
	check(warned, "venom at a marked spot")


func test_ursa_assigns_euryale_at_slayer_70() -> void:
	check_eq(Slayer.required_level("euryale"), 70, "Slayer 70")
	var tasks := Slayer.eligible_tasks(ContentDB.venator("ursa"), 100, 75).map(func(t): return t["monster"])
	check(tasks.has("euryale"), "assigned at combat 100, Slayer 75")
	tasks = Slayer.eligible_tasks(ContentDB.venator("ursa"), 100, 65).map(func(t): return t["monster"])
	check(not tasks.has("euryale"), "not below Slayer 70")
