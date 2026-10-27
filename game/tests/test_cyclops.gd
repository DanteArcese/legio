extends "res://tests/test_case.gd"
## Cyclopes: heavy hitters that heave boulders at marked spots.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Slayer := preload("res://scripts/sim/slayer.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const CYCLOPS := 50


func test_a_cyclops_heaves_boulders() -> void:
	var sim := Simulation.new(9)
	var player := sim.add_player(PLAYER, Vector3.ZERO)
	player.max_hp = 500
	player.hp = 500
	player.auto_retaliate = false
	sim.add_monster(CYCLOPS, "cyclops", Vector3(1, 0, 0))
	sim.get_combatant(CYCLOPS).target_id = PLAYER
	var events := []
	for i in 60:
		events.append_array(sim.step())
	var warns := events.filter(func(e): return e["type"] == "strike_warn")
	check(not warns.is_empty(), "threw at least once")
	check(warns.all(func(e): return e["kind"] == "boulder"), "boulders")
	check(events.any(func(e): return e["type"] == "message" and "heaves a boulder" in e["text"]), "warned")


func test_cyclops_cheese_is_a_strong_food() -> void:
	check(ContentDB.item("cyclops_cheese")["heals"] > ContentDB.item("cooked_tuna")["heals"], "better than tuna")


func test_both_venatores_send_hunters_after_cyclopes() -> void:
	check(Slayer.eligible_tasks(ContentDB.venator("aulus"), 55, 1).any(func(t): return t["monster"] == "cyclops"), "Aulus at combat 55")
	check(Slayer.eligible_tasks(ContentDB.venator("ursa"), 60, 1).any(func(t): return t["monster"] == "cyclops"), "Ursa")
