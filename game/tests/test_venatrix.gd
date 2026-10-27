extends "res://tests/test_case.gd"
## Ursa the Venatrix, the frontier's Slayer master: harder contracts and
## more points, for experienced hunters only.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Slayer := preload("res://scripts/sim/slayer.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1


func _make_sim(level: int, slayer: int) -> Simulation:
	var sim := Simulation.new(17)
	var player := sim.add_player(PLAYER)
	for skill in ["attack", "strength", "defence", "vitality"]:
		player.skills.xp[skill] = Skills.xp_for_level(level)
	player.skills.xp["slayer"] = Skills.xp_for_level(slayer)
	sim.add_venator("ursa", Vector3(1, 0, 0))
	return sim


func _ask(sim: Simulation) -> Array:
	sim.queue_item_action(PLAYER, "slayer_task", {"venator": "ursa"})
	return sim.step()


func test_ursa_turns_away_low_level_hunters() -> void:
	var sim := _make_sim(30, 30)
	var events := _ask(sim)
	check(sim.get_combatant(PLAYER).slayer_task.is_empty(), "no contract")
	check(events.any(func(e): return e["type"] == "message" and "combat level 50" in e["text"]), "told the requirement")


func test_ursa_gives_big_frontier_contracts() -> void:
	var sim := _make_sim(55, 35)
	_ask(sim)
	var task: Dictionary = sim.get_combatant(PLAYER).slayer_task
	check(not task.is_empty(), "got a contract")
	check_eq(task.get("venator"), "ursa", "from Ursa")
	check(task.get("total", 0) >= 25, "a long one (%d)" % task.get("total", 0))


func test_hrodgar_contracts_need_slayer_50_and_combat_75() -> void:
	var ursa := ContentDB.venator("ursa")
	var monsters := func(combat, slayer): return Slayer.eligible_tasks(ursa, combat, slayer).map(func(t): return t["monster"])
	check(not monsters.call(74, 60).has("hrodgar"), "not at combat 74")
	check(not monsters.call(80, 49).has("hrodgar"), "not at Slayer 49")
	check(monsters.call(75, 50).has("hrodgar"), "at 75 and 50")


func test_ursa_pays_more_than_aulus() -> void:
	check(Slayer.points_for("ursa", 1) > Slayer.points_for("aulus", 1), "more per contract")
	check_eq(Slayer.points_for("ursa", 10), ContentDB.venator("ursa")["points_per_task"] * 5, "streaks apply")


func test_finishing_an_ursa_contract_pays_her_rate() -> void:
	var sim := _make_sim(60, 40)
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.slayer_task = {"monster": "rat", "remaining": 1, "total": 30, "venator": "ursa"}
	var rat := sim.add_monster(70, "rat", Vector3(1, 0, 1))
	rat.hp = 1
	player.bonuses["attack"] = 5000
	sim.queue_attack(PLAYER, 70)
	for i in 20:
		sim.step()
	check_eq(player.slayer_points, ContentDB.venator("ursa")["points_per_task"], "Ursa's rate")
