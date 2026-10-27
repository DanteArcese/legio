extends "res://tests/test_case.gd"
## Gorgons: unwarded, the gaze always lands, drains like a basilisk's and
## the blows land harder. A mirror shield, the Crown of Regulus or the
## Aegis wards it.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const Slayer := preload("res://scripts/sim/slayer.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const GORGON := 50


func _make_sim(shield := "", head := "") -> Simulation:
	var sim := Simulation.new(12)
	var player := sim.add_player(PLAYER, Vector3(1, 0, 1))
	for skill in ["attack", "strength", "defence", "vitality", "slayer"]:
		player.skills.xp[skill] = Skills.xp_for_level(70)
	player.equipment.worn["shield"] = shield
	player.equipment.worn["head"] = head
	player.apply_equipment()
	return sim


## Lets a gorgon attack for a while; returns the damage of every hit.
func _gaze(sim: Simulation, ticks: int) -> Array:
	var player: RefCounted = sim.get_combatant(PLAYER)
	var gorgon := sim.add_monster(GORGON, "gorgon", Vector3(1, 0, 1.5))
	gorgon.target_id = PLAYER
	var hits := []
	for i in ticks:
		for e in sim.step():
			if e["type"] == "hit" and e["attacker"] == GORGON:
				hits.append(e["damage"])
		player.hp = player.max_hp
	return hits


func test_unwarded_the_gaze_always_lands_and_drains() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.bonuses["defence"] = 5000
	var hits := _gaze(sim, 60)
	check(hits.size() > 5 and hits.all(func(d): return d > 0), "every blow lands despite huge defence (%s)" % [hits])
	check(player.remedy_boost("defence") < 0, "and drains")


func test_unwarded_blows_land_harder() -> void:
	var gorgon_max: int = Simulation.new(1).add_monster(GORGON, "gorgon", Vector3.ZERO).max_hit()
	var hits := _gaze(_make_sim(), 400)
	check(hits.max() > gorgon_max, "a blow above the normal max hit of %d (best %d)" % [gorgon_max, hits.max()])


func test_three_wards() -> void:
	for gear in [["mirror_shield", ""], ["aegis", ""], ["", "crown_of_regulus"]]:
		var sim := _make_sim(gear[0], gear[1])
		check_eq(Slayer.unwarded_effect("gorgon", sim.get_combatant(PLAYER).equipment), "", "%s%s wards the gorgon" % gear)


func test_ursa_assigns_gorgons_at_slayer_60() -> void:
	var tasks := Slayer.eligible_tasks(ContentDB.venator("ursa"), 80, 60).map(func(t): return t["monster"])
	check(tasks.has("gorgon"), "at 60")
	tasks = Slayer.eligible_tasks(ContentDB.venator("ursa"), 80, 59).map(func(t): return t["monster"])
	check(not tasks.has("gorgon"), "not at 59")
