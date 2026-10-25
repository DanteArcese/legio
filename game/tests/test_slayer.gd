extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/sim/simulation.gd")
const Slayer := preload("res://scripts/sim/slayer.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const MONSTER := 50


func _make_sim() -> Simulation:
	var sim := Simulation.new(13)
	sim.add_player(PLAYER)
	sim.add_venator("aulus", Vector3(1, 0, 0))
	return sim


func _set_levels(sim: Simulation, levels: Dictionary) -> void:
	for skill in levels:
		sim.get_combatant(PLAYER).skills.xp[skill] = Skills.xp_for_level(levels[skill])


func _ask(sim: Simulation) -> Array:
	sim.queue_item_action(PLAYER, "slayer_task", {"venator": "aulus"})
	return sim.step()


## Kills a fresh monster of this kind next to the player.
func _kill(sim: Simulation, monster_id: String, id: int) -> Array:
	var monster := sim.add_monster(id, monster_id, Vector3(1, 0, 1))
	monster.hp = 1
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.bonuses["attack"] = 5000
	player.hp = player.max_hp
	sim.queue_attack(PLAYER, id)
	var events := []
	for i in 20:
		events.append_array(sim.step())
		if not monster.is_alive():
			break
	return events


func test_fresh_player_only_gets_low_level_tasks() -> void:
	var tasks := Slayer.eligible_tasks(ContentDB.venator("aulus"), 3, 1)
	var monsters := tasks.map(func(t): return t["monster"])
	check_eq(monsters, ["rat", "wolf", "wild_boar"], "eligible at combat 3")


func test_strix_needs_slayer_10_and_combat_18() -> void:
	var venator := ContentDB.venator("aulus")
	check(not Slayer.eligible_tasks(venator, 30, 9).any(func(t): return t["monster"] == "strix"), "not at slayer 9")
	check(not Slayer.eligible_tasks(venator, 17, 10).any(func(t): return t["monster"] == "strix"), "not at combat 17")
	check(Slayer.eligible_tasks(venator, 18, 10).any(func(t): return t["monster"] == "strix"), "at 18 / 10")


func test_assignment_is_deterministic_and_in_range() -> void:
	for i in 30:
		var a := RandomNumberGenerator.new()
		var b := RandomNumberGenerator.new()
		a.seed = i
		b.seed = i
		var task := Slayer.assign("aulus", 3, 1, a)
		check_eq(task, Slayer.assign("aulus", 3, 1, b), "same seed")
		var entry: Dictionary = ContentDB.venator("aulus")["tasks"].filter(func(t): return t["monster"] == task["monster"])[0]
		check(task["total"] >= entry["amount"][0] and task["total"] <= entry["amount"][1], "amount in range")


func test_venator_assigns_a_task_in_range_only() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.position = Vector3(20, 0, 0)
	_ask(sim)
	check(player.slayer_task.is_empty(), "too far away")
	player.position = Vector3.ZERO
	var events := _ask(sim)
	check(not player.slayer_task.is_empty(), "assigned")
	check(events.any(func(e): return e["type"] == "slayer_assigned"), "event")


func test_asking_again_reports_progress_instead_of_reassigning() -> void:
	var sim := _make_sim()
	_ask(sim)
	var task: Dictionary = sim.get_combatant(PLAYER).slayer_task.duplicate()
	var events := _ask(sim)
	check_eq(sim.get_combatant(PLAYER).slayer_task, task, "same task")
	check(events.any(func(e): return e["type"] == "message" and "still need" in e["text"]), "progress message")


func test_on_task_kills_count_and_give_slayer_xp() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.slayer_task = {"monster": "rat", "remaining": 2, "total": 2, "venator": "aulus"}
	_kill(sim, "wolf", 60)
	check_eq(player.slayer_task["remaining"], 2, "off-task kill doesn't count")
	check_eq(player.skills.xp["slayer"], 0.0, "no xp off task")
	_kill(sim, "rat", 61)
	check_eq(player.slayer_task["remaining"], 1, "counted")
	check_eq(player.skills.xp["slayer"], 2.0, "xp = rat hitpoints")


func test_completing_a_task_awards_points() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.slayer_task = {"monster": "rat", "remaining": 1, "total": 5, "venator": "aulus"}
	var events := _kill(sim, "rat", 70)
	check(player.slayer_task.is_empty(), "task cleared")
	check_eq(player.slayer_points, 2, "points")
	check_eq(player.slayer_tasks_done, 1, "count")
	check(events.any(func(e): return e["type"] == "slayer_complete"), "event")


func test_slayer_level_gate_blocks_attacking() -> void:
	var sim := _make_sim()
	sim.add_monster(MONSTER, "strix", Vector3(1, 0, 1))
	sim.queue_attack(PLAYER, MONSTER)
	var events := []
	for i in 10:
		events.append_array(sim.step())
	check_eq(sim.get_combatant(PLAYER).target_id, -1, "target dropped, even after the strix attacks")
	check(events.any(func(e): return e["type"] == "message" and "Slayer 10" in e["text"]), "told why")
	check(not events.any(func(e): return e["type"] == "hit" and e["attacker"] == PLAYER), "player never attacks")


func test_strix_always_hits_and_heals_without_whitethorn() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.position = Vector3(1, 0, 1)
	player.bonuses["defence"] = 5000
	var strix := sim.add_monster(MONSTER, "strix", Vector3(1, 0, 1.5))
	strix.hp = 10
	strix.target_id = PLAYER
	var landed := 0
	var attacks := 0
	for i in 40:
		for e in sim.step():
			if e["type"] == "hit" and e["attacker"] == MONSTER:
				attacks += 1
				landed += 1 if e["damage"] > 0 else 0
		player.hp = player.max_hp
	check(attacks > 5 and landed == attacks, "landed %d of %d despite huge defence" % [landed, attacks])
	check(strix.hp > 10, "strix healed (%d)" % strix.hp)


func test_whitethorn_charm_wards_off_the_strix() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.position = Vector3(1, 0, 1)
	sim.give_item(PLAYER, "whitethorn_charm", 1, "test", [])
	sim.queue_item_action(PLAYER, "equip", {"slot": 0})
	sim.step()
	player.bonuses["defence"] = 5000
	var strix := sim.add_monster(MONSTER, "strix", Vector3(1, 0, 1.5))
	strix.target_id = PLAYER
	var landed := 0
	for i in 40:
		for e in sim.step():
			if e["type"] == "hit" and e["attacker"] == MONSTER and e["damage"] > 0:
				landed += 1
		player.hp = player.max_hp
	check(landed <= 1, "huge defence stops the warded strix (%d landed)" % landed)
