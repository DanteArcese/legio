extends "res://tests/test_case.gd"
## Region tasks: ticked off by what the simulation reports, paid by region.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Tasks := preload("res://scripts/sim/tasks.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")

const PLAYER := 1


func _make_sim() -> Simulation:
	var sim := Simulation.new(33)
	sim.add_player(PLAYER)
	return sim


func _done(sim: Simulation, key: String) -> bool:
	return sim.get_combatant(PLAYER).tasks_done.has(key)


func test_obtaining_an_item_by_skill_counts_but_buying_doesnt() -> void:
	var sim := _make_sim()
	sim.give_item(PLAYER, "copper_ore", 1, "shop", [])
	check(not _done(sim, "castra_ferrea/copper"), "bought doesn't count")
	var events := []
	sim.give_item(PLAYER, "copper_ore", 1, "skilling", events)
	check(_done(sim, "castra_ferrea/copper"), "mined counts")
	check(events.any(func(e): return e["type"] == "message" and "Task done" in e["text"]), "announced")


func test_kills_quests_levels_and_visits() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	var wolf := sim.add_monster(50, "wolf", Vector3(1, 0, 1))
	wolf.last_attacker_id = PLAYER
	wolf.hp = 0
	sim.kill(wolf, [])
	check(_done(sim, "castra_ferrea/wolf"), "kill")
	sim.award_xp(player, "attack", Skills.xp_for_level(10), [])
	check(_done(sim, "castra_ferrea/attack"), "level")
	player.position = Vector3(150, 0, -20)
	for i in Tasks.VISIT_INTERVAL + 1:
		sim.step()
	check(_done(sim, "castra_ferrea/barrow"), "visit")
	sim.tasks.on_quest(player, "tiro", [])
	check(_done(sim, "castra_ferrea/tiro"), "quest")


func test_finishing_a_region_pays_once() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	var region: Dictionary = Tasks.regions()["frontier"]
	for task in region["tasks"].slice(0, region["tasks"].size() - 1):
		player.tasks_done.append(Tasks.key("frontier", task["id"]))
	var events := []
	sim.tasks.on_kill(player, "hrodgar", events)
	check_eq(player.inventory.count("coins"), region["reward"], "paid")
	check(events.any(func(e): return e["type"] == "region_tasks_done"), "region done")
	check_eq(Tasks.progress(player, "frontier"), [region["tasks"].size(), region["tasks"].size()], "all done")


func test_tasks_are_saved() -> void:
	var sim := _make_sim()
	sim.get_combatant(PLAYER).tasks_done = ["castra_ferrea/logs"]
	var text := SaveGame.to_json(SaveGame.capture(sim, PLAYER))
	var loaded := _make_sim()
	SaveGame.restore(loaded, PLAYER, SaveGame.from_json(text))
	check_eq(loaded.get_combatant(PLAYER).tasks_done, ["castra_ferrea/logs"], "kept")
