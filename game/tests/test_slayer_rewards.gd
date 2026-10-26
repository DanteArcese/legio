extends "res://tests/test_case.gd"
## Spending Slayer points: cancelling, blocking, streak bonuses, and the
## venator's helm.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Slayer := preload("res://scripts/sim/slayer.gd")
const Skilling := preload("res://scripts/sim/skilling.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const MONSTER := 50
const WOLVES := {"monster": "wolf", "remaining": 20, "total": 20, "venator": "aulus"}


func _make_sim() -> Simulation:
	var sim := Simulation.new(21)
	sim.add_player(PLAYER)
	sim.add_venator("aulus", Vector3(1, 0, 0))
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _reward(sim: Simulation, reward: String, args := {}) -> Array:
	var command := args.duplicate()
	command["venator"] = "aulus"
	command["reward"] = reward
	sim.queue_item_action(PLAYER, "slayer_reward", command)
	return sim.step()


func _messages(events: Array) -> String:
	return " | ".join(events.filter(func(e): return e["type"] == "message").map(func(e): return e["text"]))


func test_cancelling_costs_points_and_clears_the_task() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	player.slayer_task = WOLVES.duplicate()
	player.slayer_points = 20
	_reward(sim, "cancel")
	check(player.slayer_task.is_empty(), "task cleared")
	check_eq(player.slayer_points, 20 - ContentDB.slayer_rewards()["cancel"], "paid")


func test_cannot_afford_a_cancel() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	player.slayer_task = WOLVES.duplicate()
	player.slayer_points = 3
	var events := _reward(sim, "cancel")
	check_eq(player.slayer_task["monster"], "wolf", "task kept")
	check_eq(player.slayer_points, 3, "nothing spent")
	check("costs" in _messages(events), "told the price")


func test_rewards_need_the_venator_nearby() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	player.position = Vector3(40, 0, 40)
	player.slayer_task = WOLVES.duplicate()
	player.slayer_points = 100
	_reward(sim, "cancel")
	check_eq(player.slayer_points, 100, "nothing happens far away")


func test_blocked_monsters_are_never_assigned() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	player.slayer_task = WOLVES.duplicate()
	player.slayer_points = 100
	_reward(sim, "block")
	check_eq(player.slayer_blocked, ["wolf"], "wolf blocked")
	check(player.slayer_task.is_empty(), "and the contract dropped")
	for i in 40:
		var task := Slayer.assign("aulus", 3, 1, sim.rng, player.slayer_blocked)
		check(task["monster"] != "wolf", "assigned %s" % task["monster"])


func test_block_limit_and_unblocking() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	var limit: int = ContentDB.slayer_rewards()["max_blocks"]
	player.slayer_blocked = ["rat", "wolf", "wild_boar", "latro"].slice(0, limit)
	player.slayer_task = {"monster": "lemur", "remaining": 5, "total": 5, "venator": "aulus"}
	player.slayer_points = 500
	_reward(sim, "block")
	check_eq(player.slayer_blocked.size(), limit, "no more than the limit")
	check_eq(player.slayer_points, 500, "nothing spent")
	_reward(sim, "unblock", {"monster": "rat"})
	check(not player.slayer_blocked.has("rat"), "rat unblocked")
	check_eq(player.slayer_points, 500, "unblocking is free")


func test_every_tenth_contract_pays_a_streak_bonus() -> void:
	var base: int = ContentDB.venator("aulus")["points_per_task"]
	check_eq(Slayer.points_for("aulus", 9), base, "9th")
	check_eq(Slayer.points_for("aulus", 10), base * 5, "10th")
	check_eq(Slayer.points_for("aulus", 50), base * 15, "50th, not 10th")
	check_eq(Slayer.points_for("aulus", 60), base * 5, "60th")


func test_the_helm_is_learned_then_sewn() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	var recipe := ContentDB.recipe("leatherwork", "venators_helm")
	check(not Skilling.knows_recipe(player, recipe), "unknown at first")
	player.slayer_points = ContentDB.slayer_rewards()["unlocks"]["venators_helm"]["cost"]
	_reward(sim, "unlock", {"unlock": "venators_helm"})
	check_eq(player.slayer_points, 0, "paid")
	check(Skilling.knows_recipe(player, recipe), "learned")
	_reward(sim, "unlock", {"unlock": "venators_helm"})
	check_eq(player.slayer_unlocks.size(), 1, "bought once")


func test_the_helm_counts_as_a_whitethorn_charm() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	check_eq(Slayer.unwarded_effect("strix", player.equipment), "drain_vitality", "unwarded")
	player.equipment.worn["head"] = "venators_helm"
	check_eq(Slayer.unwarded_effect("strix", player.equipment), "", "the helm wards")


func test_the_helm_boosts_only_against_the_task_monster() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	var wolf := sim.add_monster(MONSTER, "wolf", Vector3(1, 0, 1))
	var rat := sim.add_monster(MONSTER + 1, "rat", Vector3(1, 0, 1))
	player.slayer_task = WOLVES.duplicate()
	check_eq(Slayer.boost(player, wolf), 1.0, "no helm, no boost")
	player.equipment.worn["head"] = "venators_helm"
	check(is_equal_approx(Slayer.boost(player, wolf), 1.15), "on task: %s" % Slayer.boost(player, wolf))
	check_eq(Slayer.boost(player, rat), 1.0, "off task")
	check_eq(Slayer.boost(wolf, player), 1.0, "monsters never get it")


func test_blocks_and_unlocks_survive_a_save() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	player.slayer_blocked = ["rat"]
	player.slayer_unlocks = ["venators_helm"]
	var text := SaveGame.to_json(SaveGame.capture(sim, PLAYER))
	var loaded := _make_sim()
	SaveGame.restore(loaded, PLAYER, SaveGame.from_json(text))
	check_eq(_player(loaded).slayer_blocked, ["rat"], "blocked")
	check_eq(_player(loaded).slayer_unlocks, ["venators_helm"], "unlocks")
