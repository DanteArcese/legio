extends "res://tests/test_case.gd"
## Slayer point unlocks beyond the helm: a fifth and sixth block, and longer
## contracts on chosen monsters.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Slayer := preload("res://scripts/sim/slayer.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1


func _make_sim() -> Simulation:
	var sim := Simulation.new(1)
	sim.add_player(PLAYER)
	sim.add_venator("aulus", Vector3(1, 0, 0))
	return sim


func _reward(sim: Simulation, reward: String, args := {}) -> Array:
	var command := {"venator": "aulus", "reward": reward}
	command.merge(args)
	sim.queue_item_action(PLAYER, "slayer_reward", command)
	return sim.step()


func test_extra_blocks_raise_the_cap() -> void:
	check_eq(Slayer.max_blocks([]), 4, "four to start")
	check_eq(Slayer.max_blocks(["fifth_block"]), 5, "a fifth")
	check_eq(Slayer.max_blocks(["fifth_block", "sixth_block", "venators_helm"]), 6, "and a sixth; other unlocks don't count")
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.slayer_points = 1000
	player.slayer_blocked = ["rat", "goat", "wolf", "wild_boar"]
	player.slayer_task = {"monster": "latro", "remaining": 5, "total": 5, "venator": "aulus"}
	var events := _reward(sim, "block")
	check(events.any(func(e): return e["type"] == "message" and "more than 4" in e["text"]), "full at four")
	_reward(sim, "unlock", {"unlock": "fifth_block"})
	_reward(sim, "block")
	check(player.slayer_blocked.has("latro"), "a fifth block once bought")
	check_eq(player.slayer_points, 1000 - 100 - 50, "paid for the unlock and the block")


func test_longer_contracts() -> void:
	var lengths := []
	for unlocks in [[], ["longer_basilisks"]]:
		var total := 0
		for i in 40:
			var rng := RandomNumberGenerator.new()
			rng.seed = i
			var task := {}
			while task.get("monster", "") != "basilisk":
				task = Slayer.assign("aulus", 99, 99, rng, [], unlocks)
			total += task["total"]
		lengths.append(total)
	check(lengths[1] >= lengths[0] * 1.4, "half as long again on average (%d vs %d)" % lengths)
	check(not Slayer.extended(["longer_basilisks"], "gorgon"), "only the monster bought")


func test_every_extension_names_a_task_monster() -> void:
	var assigned := {}
	for venator in ContentDB.data()["slayer"]["venatores"].values():
		for task in venator["tasks"]:
			assigned[task["monster"]] = true
	for unlock in ContentDB.slayer_rewards()["unlocks"].values():
		if unlock.has("extends"):
			check(assigned.has(unlock["extends"]), "%s is ever assigned" % unlock["extends"])
