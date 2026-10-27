extends "res://tests/test_case.gd"
## Basilisks: their gaze drains an unwarded player's melee levels, and a
## mirror shield turns it back.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const Slayer := preload("res://scripts/sim/slayer.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const BASILISK := 50


func _make_sim(shield := "") -> Simulation:
	var sim := Simulation.new(6)
	var player := sim.add_player(PLAYER, Vector3(1, 0, 1))
	for skill in ["attack", "strength", "defence", "vitality", "slayer"]:
		player.skills.xp[skill] = Skills.xp_for_level(50)
	player.equipment.worn["shield"] = shield
	player.apply_equipment()
	player.hp = player.max_hp
	return sim


## Lets a basilisk attack the player for a while, keeping them alive.
func _gaze(sim: Simulation, ticks: int) -> Array:
	var player: RefCounted = sim.get_combatant(PLAYER)
	var basilisk := sim.add_monster(BASILISK, "basilisk", Vector3(1, 0, 1.5))
	basilisk.target_id = PLAYER
	var events := []
	for i in ticks:
		events.append_array(sim.step())
		player.hp = player.max_hp
	return events


func test_the_gaze_drains_melee_levels() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	var events := _gaze(sim, 30)
	for skill in ["attack", "strength", "defence"]:
		check(player.remedy_boost(skill) < 0, "%s drained (%d)" % [skill, player.remedy_boost(skill)])
	check(player.effective_level("attack") < 50 + 8, "effective attack falls")
	check(events.filter(func(e): return e["type"] == "message" and "gaze" in e["text"]).size() == 1, "told once")


func test_the_drain_stops_at_thirty_percent() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	_gaze(sim, 400)
	check_eq(player.remedy_boost("defence"), -15, "drained to -15 at level 50, no further")


func test_drains_recover_a_level_at_a_time() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.remedy_boosts["attack"] = {"amount": -2, "next_decay": sim.tick + 1}
	for i in 5:
		sim.step()
	check_eq(player.remedy_boost("attack"), -1, "one level back")
	for i in 200:
		sim.step()
	check_eq(player.remedy_boost("attack"), 0, "fully recovered")
	check(not player.remedy_boosts.has("attack"), "and cleared")


func test_a_mirror_shield_wards_the_gaze() -> void:
	var sim := _make_sim("mirror_shield")
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.bonuses["defence"] = 5000
	var events := _gaze(sim, 40)
	check_eq(player.remedy_boost("attack"), 0, "no drain")
	check(events.filter(func(e): return e["type"] == "hit" and e["attacker"] == BASILISK and e["damage"] > 0).size() <= 1, "huge defence works")


func test_the_mirror_shield_is_smithed_with_silver() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.skills.xp["smithing"] = Skills.xp_for_level(30)
	for entry in [["bronze_bar", 3], ["silver_bar", 1], ["hammer", 1]]:
		sim.give_item(PLAYER, entry[0], entry[1], "test", [])
	sim.skilling.add_station("anvil", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "craft", {"kind": "smith", "recipe": "mirror_shield", "count": 1})
	for i in 10:
		sim.step()
	check_eq(player.inventory.count("mirror_shield"), 1, "smithed")


func test_both_venatores_assign_basilisks_at_slayer_40() -> void:
	for venator in ["aulus", "ursa"]:
		var tasks := Slayer.eligible_tasks(ContentDB.venator(venator), 60, 40).map(func(t): return t["monster"])
		check(tasks.has("basilisk"), "%s at 40" % venator)
		tasks = Slayer.eligible_tasks(ContentDB.venator(venator), 60, 39).map(func(t): return t["monster"])
		check(not tasks.has("basilisk"), "%s not at 39" % venator)


func test_the_drain_never_takes_a_level_below_one() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	for skill in ["attack", "strength", "defence"]:
		player.skills.xp[skill] = 0.0
	_gaze(sim, 60)
	check_eq(player.remedy_boost("attack"), 0, "level 1 can't be drained")
	check_eq(player.effective_level("attack") > 0, true, "still a fighter")
