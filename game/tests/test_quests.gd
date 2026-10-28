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
	check("Defence 5" in _dialogue(_talk(sim))[0], "afterwards he points at the next rank, Miles")


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


func _finish_tiro(sim: Simulation) -> void:
	_player(sim).quests["tiro"] = {"step": 5, "progress": 0, "done": true}


func test_miles_needs_tiro_and_defence() -> void:
	var sim := _make_sim()
	_finish_tiro(sim)
	var lines := _dialogue(_talk(sim))
	check(lines.size() == 1 and "Defence 5" in lines[0], "asks for Defence 5 (%s)" % [lines])
	check_eq(Quests.status(_player(sim), "miles"), "not_started", "not started yet")
	_player(sim).skills.xp["defence"] = _player(sim).skills.xp_for_level(5)
	_talk(sim)
	check_eq(Quests.status(_player(sim), "miles"), "in_progress", "starts at Defence 5")


func test_miles_from_wolves_to_the_barrow() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	_finish_tiro(sim)
	player.skills.xp["defence"] = player.skills.xp_for_level(5)
	_talk(sim)
	for i in 5:
		var wolf := sim.add_monster(RAT + i, "wolf", Vector3(0, 0, 1))
		wolf.last_attacker_id = PLAYER
		wolf.hp = 0
		sim.kill(wolf, [])
	check_eq(player.quests["miles"]["step"], 1, "wolves done")

	sim.give_item(PLAYER, "logs", 10, "test", [])
	sim.give_item(PLAYER, "bronze_nails", 10, "test", [])
	_talk(sim)
	check_eq(player.quests["miles"]["step"], 1, "not enough nails: still waiting")
	check_eq(player.inventory.count("logs"), 10, "nothing taken")
	sim.give_item(PLAYER, "bronze_nails", 5, "test", [])
	var lines := _dialogue(_talk(sim))
	check_eq(player.quests["miles"]["step"], 2, "delivered")
	check_eq(player.inventory.count("logs") + player.inventory.count("bronze_nails"), 0, "items handed over")
	check(lines[0].begins_with("You hand over 10 logs and 15 bronze nails"), "says what was handed over (%s)" % [lines])

	sim.set_position(PLAYER, Vector3(-44, 0, -34))
	_run(sim, 1)
	check_eq(player.quests["miles"]["step"], 3, "scouted the barrow")
	sim.set_position(PLAYER, Vector3(1, 0, 0))
	_talk(sim)
	check(Quests.is_done(player, "miles"), "complete")
	check_eq(Quests.rank(player), "Miles", "rank goes up")
	check_eq(player.inventory.count("lorica_hamata"), 1, "mail reward")


func test_quartermaster_keeps_mail_for_miles() -> void:
	var sim := _make_sim()
	sim.add_shopkeeper("quartermaster", Vector3(1, 0, 0))
	sim.give_item(PLAYER, "coins", 1000, "test", [])
	_finish_tiro(sim)
	sim.queue_item_action(PLAYER, "buy", {"shop": "quartermaster", "item": "lorica_hamata"})
	_run(sim, 1)
	check_eq(_player(sim).inventory.count("lorica_hamata"), 0, "not for a tiro")
	_player(sim).quests["miles"] = {"step": 4, "progress": 0, "done": true}
	sim.queue_item_action(PLAYER, "buy", {"shop": "quartermaster", "item": "lorica_hamata"})
	_run(sim, 1)
	check_eq(_player(sim).inventory.count("lorica_hamata"), 1, "a miles may buy it")


func test_duplicarius_from_the_forum_to_the_road() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	sim.quests.add_npc("gallic_merchant", Vector3(-1, 0, 0))
	player.quests["tiro"] = {"step": 5, "progress": 0, "done": true}
	player.quests["miles"] = {"step": 4, "progress": 0, "done": true}
	var lines := _dialogue(_talk(sim))
	check("Attack 15" in lines[0], "needs Attack 15 (%s)" % [lines])
	player.skills.xp["attack"] = player.skills.xp_for_level(15)
	player.skills.xp["thieving"] = player.skills.xp_for_level(5)
	_talk(sim)
	check_eq(Quests.status(player, "duplicarius"), "in_progress", "started")

	sim.queue_item_action(PLAYER, "talk", {"npc": "gallic_merchant"})
	_run(sim, 1)
	check_eq(player.quests["duplicarius"]["step"], 1, "the merchant points at the latro")

	var latro := sim.add_monster(RAT, "latro", Vector3(0, 0, 1))
	latro.last_attacker_id = PLAYER
	latro.hp = 0
	sim.kill(latro, [])
	check_eq(player.inventory.count("stolen_pay_chest"), 1, "the kill hands over the chest")
	check_eq(player.quests["duplicarius"]["step"], 2, "now bring it back")

	var events := _talk(sim)
	check(Quests.is_done(player, "duplicarius"), "the delivery finishes the quest")
	check_eq(player.inventory.count("stolen_pay_chest"), 0, "chest handed over")
	check_eq(player.inventory.count("spatha"), 1, "spatha reward")
	check_eq(Quests.rank(player), "Duplicarius", "rank")
	var completion: Array = ContentDB.quest("duplicarius")["complete"]
	check_eq(_dialogue(events), completion, "shows the completion dialogue, not the hand-over")


func test_quartermaster_sells_spathae_to_duplicarii() -> void:
	var sim := _make_sim()
	sim.add_shopkeeper("quartermaster", Vector3(1, 0, 0))
	sim.give_item(PLAYER, "coins", 1000, "test", [])
	for quest_id in ["tiro", "miles"]:
		_player(sim).quests[quest_id] = {"step": 9, "progress": 0, "done": true}
	sim.queue_item_action(PLAYER, "buy", {"shop": "quartermaster", "item": "spatha"})
	_run(sim, 1)
	check_eq(_player(sim).inventory.count("spatha"), 0, "not for a miles")
	_player(sim).quests["duplicarius"] = {"step": 3, "progress": 0, "done": true}
	sim.queue_item_action(PLAYER, "buy", {"shop": "quartermaster", "item": "spatha"})
	_run(sim, 1)
	check_eq(_player(sim).inventory.count("spatha"), 1, "for a duplicarius")


func test_markers_show_what_an_npc_has_for_you() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	check_eq(Quests.marker_for(player, "optio_gaius"), "!", "a new recruit sees a quest to start")
	_talk(sim)
	check_eq(Quests.marker_for(player, "optio_gaius"), "", "nothing while the steps are under way")
	player.quests["tiro"]["step"] = 4
	check_eq(Quests.marker_for(player, "optio_gaius"), "?", "ready to report")
	player.quests["tiro"] = {"step": 5, "progress": 0, "done": true}
	check_eq(Quests.marker_for(player, "optio_gaius"), "", "Miles needs Defence 5 first")
	player.skills.xp["defence"] = player.skills.xp_for_level(5)
	check_eq(Quests.marker_for(player, "optio_gaius"), "!", "Miles on offer")
	_talk(sim)
	player.quests["miles"]["step"] = 1
	check_eq(Quests.marker_for(player, "optio_gaius"), "", "a delivery waits until you carry the goods")
	sim.give_item(PLAYER, "logs", 10, "test", [])
	sim.give_item(PLAYER, "bronze_nails", 15, "test", [])
	check_eq(Quests.marker_for(player, "optio_gaius"), "?", "goods in hand")


func test_the_larva_needs_black_beans_carried() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	player.skills.xp["attack"] = player.skills.xp_for_level(70)
	player.skills.xp["strength"] = player.skills.xp_for_level(70)
	player.skills.xp["slayer"] = player.skills.xp_for_level(15)
	var larva := sim.add_monster(RAT, "larva", Vector3(0, 0, 1))
	larva.can_fight = false
	sim.queue_attack(PLAYER, RAT)
	var events := _run(sim, 30)
	var damage := 0
	for e in events:
		if e["type"] == "hit" and e["attacker"] == PLAYER:
			damage += e["damage"]
	check_eq(damage, 0, "blows pass through it without the beans")
	sim.give_item(PLAYER, "black_beans", 9, "test", [])
	events = _run(sim, 30)
	damage = 0
	for e in events:
		if e["type"] == "hit" and e["attacker"] == PLAYER:
			damage += e["damage"]
	check(damage > 0, "the beans in your pack let you hurt it")


func test_decurio_ends_in_citizenship() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	sim.quests.add_npc("sacerdos", Vector3(-1, 0, 0))
	for quest_id in ["tiro", "miles", "duplicarius"]:
		player.quests[quest_id] = {"step": 9, "progress": 0, "done": true}
	player.skills.xp["defence"] = player.skills.xp_for_level(25)
	player.skills.xp["slayer"] = player.skills.xp_for_level(15)
	check_eq(Quests.title(player), "Duplicarius of the auxilia", "a duplicarius so far")
	_talk(sim)
	check_eq(Quests.status(player, "decurio"), "in_progress", "started")
	check_eq(Quests.marker_for(player, "sacerdos"), "?", "the sacerdos is marked")
	sim.queue_item_action(PLAYER, "talk", {"npc": "sacerdos"})
	_run(sim, 1)
	check_eq(player.inventory.count("black_beans"), 9, "nine black beans")
	var larva := sim.add_monster(RAT, "larva", Vector3(0, 0, 1))
	larva.last_attacker_id = PLAYER
	larva.hp = 0
	sim.kill(larva, [])
	_talk(sim)
	check(Quests.is_done(player, "decurio"), "complete")
	check_eq(Quests.title(player), "Civis Romanus", "a citizen of Rome")
	check_eq(player.inventory.count("diploma"), 1, "the bronze diploma")


func test_harpies_at_the_harbour() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	sim.quests.add_npc("harbourmaster", Vector3(1, 0, 0))
	sim.quests.add_npc("fishmonger", Vector3(-1, 0, 0))
	player.skills.xp["slayer"] = player.skills.xp_for_level(20)
	player.skills.xp["fishing"] = player.skills.xp_for_level(15)
	sim.queue_item_action(PLAYER, "talk", {"npc": "harbourmaster"})
	_run(sim, 1)
	check_eq(Quests.status(player, "harpies_at_the_harbour"), "in_progress", "started")
	for i in 4:
		var harpy := sim.add_monster(RAT + i, "harpy", Vector3(0, 0, 1))
		harpy.last_attacker_id = PLAYER
		harpy.hp = 0
		sim.kill(harpy, [])
	check_eq(player.quests["harpies_at_the_harbour"]["step"], 1, "four harpies")
	sim.give_item(PLAYER, "harpy_feather", 3, "test", [])
	sim.queue_item_action(PLAYER, "talk", {"npc": "harbourmaster"})
	_run(sim, 1)
	check_eq(player.quests["harpies_at_the_harbour"]["step"], 2, "feathers delivered")
	sim.give_item(PLAYER, "linen", 2, "test", [])
	sim.queue_item_action(PLAYER, "talk", {"npc": "fishmonger"})
	_run(sim, 1)
	check_eq(player.quests["harpies_at_the_harbour"]["step"], 3, "linen for the nets")
	sim.queue_item_action(PLAYER, "talk", {"npc": "harbourmaster"})
	_run(sim, 1)
	check(Quests.is_done(player, "harpies_at_the_harbour"), "complete")
	check_eq(player.inventory.count("harpy_arrow"), 60, "harpy arrows")


func test_harpy_arrows_are_taught_by_the_quest() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	player.skills.xp["fletching"] = player.skills.xp_for_level(30)
	sim.give_item(PLAYER, "arrow_shaft", 15, "test", [])
	sim.give_item(PLAYER, "harpy_feather", 1, "test", [])
	sim.give_item(PLAYER, "iron_arrowheads", 15, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "fletch", "recipe": "harpy_arrow", "count": 1})
	var events := _run(sim, 6)
	check(events.any(func(e): return e["type"] == "message" and "don't know how" in e["text"]), "not yet")
	player.quests["harpies_at_the_harbour"] = {"step": 4, "progress": 0, "done": true}
	sim.queue_item_action(PLAYER, "craft", {"kind": "fletch", "recipe": "harpy_arrow", "count": 1})
	_run(sim, 6)
	check_eq(player.inventory.count("harpy_arrow"), 15, "fletched after the quest")


func test_the_lost_eagle() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	sim.quests.add_npc("centurion_varro", Vector3(1, 0, 0))
	for skill in ["attack", "strength", "defence"]:
		player.skills.xp[skill] = player.skills.xp_for_level(45)
	player.quests["duplicarius"] = {"step": 0, "progress": 0, "done": true}
	sim.queue_item_action(PLAYER, "talk", {"npc": "centurion_varro"})
	_run(sim, 1)
	check_eq(Quests.status(player, "the_lost_eagle"), "in_progress", "started")
	sim.set_position(PLAYER, Vector3(24, 0, -412))
	_run(sim, 1)
	check_eq(player.quests["the_lost_eagle"]["step"], 1, "scouted the camp")
	for i in 4:
		var raider := sim.add_monster(RAT + i, "germanic_raider", Vector3(24, 0, -411))
		raider.last_attacker_id = PLAYER
		raider.hp = 0
		sim.kill(raider, [])
	check_eq(player.quests["the_lost_eagle"]["step"], 2, "four raiders")
	var hrodgar := sim.add_monster(RAT + 10, "hrodgar", Vector3(24, 0, -411))
	hrodgar.last_attacker_id = PLAYER
	hrodgar.hp = 0
	sim.kill(hrodgar, [])
	check_eq(player.inventory.count("legion_eagle"), 1, "the eagle taken back")
	sim.set_position(PLAYER, Vector3.ZERO)
	sim.queue_item_action(PLAYER, "talk", {"npc": "centurion_varro"})
	_run(sim, 1)
	check(Quests.is_done(player, "the_lost_eagle"), "complete")
	check_eq(player.inventory.count("legion_eagle"), 0, "the eagle handed over")


func test_gold_torcs_are_taught_by_the_lost_eagle() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	player.skills.xp["smithing"] = player.skills.xp_for_level(45)
	sim.skilling.add_station("anvil", Vector3(1, 0, 0))
	sim.give_item(PLAYER, "hammer", 1, "test", [])
	sim.give_item(PLAYER, "gold_bar", 2, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "smith", "recipe": "gold_torc", "count": 1})
	var events := _run(sim, 8)
	check(events.any(func(e): return e["type"] == "message" and "don't know how" in e["text"]), "not yet")
	player.quests["the_lost_eagle"] = {"step": 4, "progress": 0, "done": true}
	sim.queue_item_action(PLAYER, "craft", {"kind": "smith", "recipe": "gold_torc", "count": 1})
	_run(sim, 8)
	check_eq(player.inventory.count("gold_torc"), 1, "smithed after the quest")


func test_the_silent_gallery() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	sim.quests.add_npc("procurator", Vector3(1, 0, 0))
	sim.quests.add_npc("foreman_masculus", Vector3(-1, 0, 0))
	sim.queue_item_action(PLAYER, "talk", {"npc": "procurator"})
	_run(sim, 1)
	check_eq(Quests.status(player, "the_silent_gallery"), "not_started", "needs Mining, Smithing and Slayer")
	for skill in ["mining", "smithing"]:
		player.skills.xp[skill] = player.skills.xp_for_level(30)
	player.skills.xp["slayer"] = player.skills.xp_for_level(40)
	sim.queue_item_action(PLAYER, "talk", {"npc": "procurator"})
	_run(sim, 1)
	check_eq(Quests.status(player, "the_silent_gallery"), "in_progress", "started")
	sim.queue_item_action(PLAYER, "talk", {"npc": "foreman_masculus"})
	var events := _run(sim, 1)
	check(_dialogue(events).any(func(line): return "polished bronze" in line), "the foreman explains the mirror")
	check_eq(player.quests["the_silent_gallery"]["step"], 1, "talked to the foreman")
	for i in 4:
		var basilisk := sim.add_monster(RAT + i, "basilisk", Vector3(0, 0, 1))
		basilisk.last_attacker_id = PLAYER
		basilisk.hp = 0
		sim.kill(basilisk, [])
	check_eq(player.quests["the_silent_gallery"]["step"], 2, "four basilisks")
	sim.give_item(PLAYER, "silver_bar", 5, "test", [])
	sim.queue_item_action(PLAYER, "talk", {"npc": "procurator"})
	_run(sim, 1)
	check_eq(player.quests["the_silent_gallery"]["step"], 3, "quota delivered")
	check_eq(player.inventory.count("silver_bar"), 0, "the bars handed over")
	sim.queue_item_action(PLAYER, "talk", {"npc": "procurator"})
	_run(sim, 1)
	check(Quests.is_done(player, "the_silent_gallery"), "complete")
	check_eq(player.inventory.count("coins"), 2000, "the fee")


func test_the_shepherds_flock() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	sim.quests.add_npc("melissa", Vector3(1, 0, 0))
	for skill in ["attack", "strength", "defence"]:
		player.skills.xp[skill] = player.skills.xp_for_level(45)
	sim.queue_item_action(PLAYER, "talk", {"npc": "melissa"})
	_run(sim, 1)
	check_eq(Quests.status(player, "the_shepherds_flock"), "in_progress", "started")
	for i in 4:
		var cyclops := sim.add_monster(RAT + i, "cyclops", Vector3(0, 0, 1))
		cyclops.last_attacker_id = PLAYER
		cyclops.hp = 0
		sim.kill(cyclops, [])
	check_eq(player.quests["the_shepherds_flock"]["step"], 1, "four cyclopes")
	sim.give_item(PLAYER, "cyclops_cheese", 3, "test", [])
	sim.queue_item_action(PLAYER, "talk", {"npc": "melissa"})
	var events := _run(sim, 1)
	check(_dialogue(events).any(func(line): return "thyme" in line), "she knows the cheese")
	sim.queue_item_action(PLAYER, "talk", {"npc": "melissa"})
	_run(sim, 1)
	check(Quests.is_done(player, "the_shepherds_flock"), "complete")
	check_eq(player.inventory.count("cyclops_cheese"), 5, "paid in cheese")


func _kill_for_player(sim: Simulation, id: int, monster: String) -> void:
	var target := sim.add_monster(id, monster, Vector3(0, 0, 1))
	target.last_attacker_id = PLAYER
	target.hp = 0
	sim.kill(target, [])


func test_sacramentum_and_optio() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	sim.quests.add_npc("centurion_varro", Vector3(1, 0, 0))
	sim.quests.add_npc("sacerdos", Vector3(-1, 0, 0))
	sim.quests.add_npc("melissa", Vector3(0, 0, -1))
	for quest_id in ["decurio", "the_lost_eagle"]:
		player.quests[quest_id] = {"step": 0, "progress": 0, "done": true}
	for skill in ["attack", "strength", "defence"]:
		player.skills.xp[skill] = player.skills.xp_for_level(40)
	var talk := func(npc: String) -> Array:
		sim.queue_item_action(PLAYER, "talk", {"npc": npc})
		return _run(sim, 1)
	talk.call("centurion_varro")
	check_eq(Quests.status(player, "sacramentum"), "in_progress", "Varro swears in a citizen")
	sim.give_item(PLAYER, "wine", 1, "test", [])
	sim.give_item(PLAYER, "incense", 5, "test", [])
	talk.call("sacerdos")
	check_eq(player.quests["sacramentum"]["step"], 1, "the sacrifice made")
	check_eq(player.inventory.count("incense"), 0, "incense burned")
	for i in 8:
		_kill_for_player(sim, RAT + i, "germanic_raider")
	check_eq(player.quests["sacramentum"]["step"], 2, "eight raiders")
	sim.give_item(PLAYER, "steel_scutum", 1, "test", [])
	sim.give_item(PLAYER, "steel_pilum", 10, "test", [])
	talk.call("centurion_varro")
	check(Quests.is_done(player, "sacramentum"), "sworn in")
	check_eq(Quests.rank(player), "Legionarius", "a legionary")
	check_eq(Quests.title(player), "Miles legionis", "the title")
	check_eq(player.inventory.count("lorica_segmentata"), 1, "a lorica segmentata")
	check_eq(player.inventory.count("steel_scutum"), 1, "the scutum back")

	var lines := _dialogue(talk.call("centurion_varro"))
	check(lines.size() > 0 and "Slayer 60" in " ".join(lines) or Quests.unmet_requirement(player, "optio") != "", "Optio is locked for now")
	for skill in ["attack", "strength", "defence", "slayer"]:
		player.skills.xp[skill] = player.skills.xp_for_level(60)
	talk.call("centurion_varro")
	check_eq(Quests.status(player, "optio"), "in_progress", "Optio started")
	talk.call("melissa")
	check_eq(player.quests["optio"]["step"], 1, "Melissa points at the ruins")
	for i in 3:
		_kill_for_player(sim, RAT + 20 + i, "gorgon")
	check_eq(player.inventory.count("gorgon_head"), 1, "the head, in a sack")
	talk.call("centurion_varro")
	check(Quests.is_done(player, "optio"), "an optio")
	check_eq(Quests.rank(player), "Optio", "the rank")
	check_eq(player.inventory.count("phalerae"), 1, "phalerae for valour")
	check_eq(player.inventory.count("gorgon_head"), 0, "the head handed over")
