extends "res://tests/test_case.gd"
## The quest system, through Tiro: the first rank of the auxilia career.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Quests := preload("res://scripts/sim/quests.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const DUMMY := 100
const RAT := 200


func _make_sim() -> Simulation:
	var sim := Simulation.new(9)
	sim.add_player(PLAYER)
	sim.quests.add_npc("optio_gaius", Vector3(1, 0, 0))
	var dummy := sim.add_combatant(DUMMY)
	dummy.max_hp = 1000
	dummy.hp = 1000
	dummy.can_fight = false
	dummy.auto_retaliate = false
	dummy.tag = "training_dummy"
	dummy.position = Vector3(1, 0, 1)
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _run(sim: Simulation, ticks: int) -> Array:
	var events := []
	for i in ticks:
		events.append_array(sim.step())
	return events


func _talk(sim: Simulation) -> Array:
	sim.queue_item_action(PLAYER, "talk", {"npc": "optio_gaius"})
	return _run(sim, 1)


func _dialogue(events: Array) -> Array:
	for event in events:
		if event["type"] == "dialogue":
			return event["lines"]
	return []


func _wield(sim: Simulation, weapon: String, ammo := "") -> void:
	var player := _player(sim)
	for item_id in [weapon, ammo]:
		if item_id.is_empty():
			continue
		for i in player.inventory.size:
			var slot: Variant = player.inventory.slots[i]
			if slot and slot["item"] == item_id:
				sim.queue_item_action(PLAYER, "equip", {"slot": i})
				_run(sim, 1)
				break


func _attack_dummy(sim: Simulation, ticks: int) -> void:
	sim.queue_attack(PLAYER, DUMMY)
	_run(sim, ticks)
	sim.queue_stop(PLAYER)
	_run(sim, 1)


func test_talking_starts_tiro_and_hands_out_kit() -> void:
	var sim := _make_sim()
	var events := _talk(sim)
	check_eq(Quests.status(_player(sim), "tiro"), "in_progress", "started")
	check(_dialogue(events).size() > 1, "the optio explains")
	for item_id in ["sling", "lead_glans", "lituus", "binding_tablet"]:
		check(_player(sim).inventory.count(item_id) > 0, "given " + item_id)
	check(events.any(func(e): return e["type"] == "quest_started"), "quest_started event")


func test_talking_again_reminds_of_the_current_step() -> void:
	var sim := _make_sim()
	_talk(sim)
	var lines := _dialogue(_talk(sim))
	check_eq(lines, ContentDB.quest("tiro")["steps"][0]["remind"], "reminder for step one")
	check(_player(sim).inventory.count("sling") == 1, "kit not handed out twice")


func test_talking_out_of_range_does_nothing() -> void:
	var sim := _make_sim()
	sim.set_position(PLAYER, Vector3(20, 0, 0))
	check(_dialogue(_talk(sim)).is_empty(), "no answer from afar")
	check_eq(Quests.status(_player(sim), "tiro"), "not_started", "not started")


func test_only_the_right_style_counts() -> void:
	var sim := _make_sim()
	_talk(sim)
	_wield(sim, "sling", "lead_glans")
	_attack_dummy(sim, 20)
	check_eq(_player(sim).quests["tiro"]["step"], 0, "sling hits don't count for the melee step")
	check_eq(_player(sim).quests["tiro"]["progress"], 0, "no progress")


func test_the_whole_quest() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	sim.give_item(PLAYER, "bronze_pugio", 1, "test", [])
	_talk(sim)
	_wield(sim, "bronze_pugio")
	_attack_dummy(sim, 40)
	check_eq(player.quests["tiro"]["step"], 1, "melee step done")
	_wield(sim, "sling", "lead_glans")
	_attack_dummy(sim, 30)
	check_eq(player.quests["tiro"]["step"], 2, "ranged step done")
	_wield(sim, "lituus", "binding_tablet")
	_attack_dummy(sim, 25)
	check_eq(player.quests["tiro"]["step"], 3, "ritus step done")
	for i in 3:
		var rat := sim.add_monster(RAT + i, "rat", Vector3(0, 0, 1))
		rat.last_attacker_id = PLAYER
		rat.hp = 0
		sim.kill(rat, [])
	check_eq(player.quests["tiro"]["step"], 4, "rats done")
	var before: float = player.skills.xp["attack"]
	var events := _talk(sim)
	check(Quests.is_done(player, "tiro"), "complete")
	check_eq(player.skills.xp["attack"] - before, 200.0, "attack xp reward")
	check_eq(player.inventory.count("parma"), 1, "parma reward")
	check_eq(Quests.rank(player), "Tiro", "rank")
	check(events.any(func(e): return e["type"] == "quest_complete"), "quest_complete event")
	check_eq(_dialogue(_talk(sim)), ContentDB.npc("optio_gaius")["idle"], "idle chatter afterwards")


func test_quartermaster_needs_tiro() -> void:
	var sim := _make_sim()
	sim.add_shopkeeper("quartermaster", Vector3(1, 0, 0))
	sim.give_item(PLAYER, "coins", 500, "test", [])
	sim.queue_item_action(PLAYER, "buy", {"shop": "quartermaster", "item": "iron_gladius"})
	_run(sim, 1)
	check_eq(_player(sim).inventory.count("iron_gladius"), 0, "locked before the quest")
	_player(sim).quests["tiro"] = {"step": 5, "progress": 0, "done": true}
	sim.queue_item_action(PLAYER, "buy", {"shop": "quartermaster", "item": "iron_gladius"})
	_run(sim, 1)
	check_eq(_player(sim).inventory.count("iron_gladius"), 1, "open after")


func test_quest_progress_survives_a_save() -> void:
	var sim := _make_sim()
	_talk(sim)
	_player(sim).quests["tiro"]["step"] = 3
	_player(sim).quests["tiro"]["progress"] = 2
	var data := SaveGame.from_json(SaveGame.to_json(SaveGame.capture(sim, PLAYER)))
	var loaded := _make_sim()
	check(SaveGame.restore(loaded, PLAYER, data), "restored")
	check_eq(_player(loaded).quests["tiro"], {"step": 3, "progress": 2, "done": false}, "same progress")
	check_eq(typeof(_player(loaded).quests["tiro"]["step"]), TYPE_INT, "ints after JSON")
