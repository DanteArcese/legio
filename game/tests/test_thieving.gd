extends "res://tests/test_case.gd"
## Thieving: market stalls, pickpocketing, and strongboxes.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Thieving := preload("res://scripts/sim/thieving.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const STALL := 1
const MARK := 1


## Outside the walls by default, so the town watch stays out of it.
func _make_sim(at := Vector3(60, 0, 0)) -> Simulation:
	var sim := Simulation.new(3)
	sim.add_player(PLAYER, at)
	sim.thieving.add_stall(STALL, "bakers_stall", at + Vector3(1, 0, 0))
	sim.thieving.add_mark(MARK, "townsman", at + Vector3(1, 0, 0))
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _run(sim: Simulation, ticks: int) -> Array:
	var events := []
	for i in ticks:
		events.append_array(sim.step())
	return events


func _steal(sim: Simulation) -> Array:
	sim.queue_item_action(PLAYER, "steal", {"stall": STALL})
	return _run(sim, 1)


func test_stealing_bread_empties_the_stall_until_it_restocks() -> void:
	var sim := _make_sim()
	var events := []
	for attempt in 20:
		events = _steal(sim)
		if _player(sim).inventory.count("bread") > 0:
			break
		_run(sim, Thieving.ATTEMPT_TICKS)
	check_eq(_player(sim).inventory.count("bread"), 1, "stole a loaf")
	check_eq(_player(sim).skills.xp["thieving"], 16.0, "thieving xp")
	check(events.any(func(e): return e["type"] == "stall_emptied"), "the stall is empty")
	_run(sim, Thieving.ATTEMPT_TICKS)
	events = _steal(sim)
	check(events.any(func(e): return e["type"] == "message" and "nothing left" in e["text"]), "nothing to take while empty")
	events = _run(sim, ContentDB.stall("bakers_stall")["restock_ticks"])
	check(events.any(func(e): return e["type"] == "stall_restocked"), "restocks")


func test_stalls_need_the_level() -> void:
	var sim := _make_sim()
	sim.thieving.add_stall(2, "silversmiths_stall", Vector3(61, 0, 0))
	sim.queue_item_action(PLAYER, "steal", {"stall": 2})
	var events := _run(sim, 1)
	check(events.any(func(e): return e["type"] == "message" and "Thieving 25" in e["text"]), "level gate")


func test_caught_inside_the_walls_brings_the_watch() -> void:
	var sim := _make_sim(Vector3(0, 0, 0))
	var player := _player(sim)
	sim.give_item(PLAYER, "coins", 100, "test", [])
	var caught := 0
	var fined := false
	for attempt in 200:
		var events := _steal(sim)
		caught += events.filter(func(e): return e["type"] == "caught").size()
		fined = fined or events.any(func(e): return e["type"] == "watch_fine")
		_run(sim, ContentDB.stall("bakers_stall")["restock_ticks"] + 2)
		if fined:
			break
	check(caught >= 2, "caught now and then (%d)" % caught)
	check(fined, "a second offence is fined")
	check(player.inventory.count("coins") < 100, "the fine was paid")


func test_pickpocketing_pays_or_stuns() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	var coins_seen := false
	var stunned_seen := false
	for attempt in 60:
		sim.queue_item_action(PLAYER, "pickpocket", {"mark": MARK})
		var events := _run(sim, 1)
		coins_seen = coins_seen or events.any(func(e): return e["type"] == "pickpocketed")
		if events.any(func(e): return e["type"] == "stunned"):
			stunned_seen = true
			check(Thieving.is_stunned(player, sim.tick), "stunned right after")
			sim.queue_item_action(PLAYER, "pickpocket", {"mark": MARK})
			var again := _run(sim, 1)
			check(not again.any(func(e): return e["type"] == "pickpocketed"), "no thieving while stunned")
		_run(sim, ContentDB.mark("townsman")["stun_ticks"] + 1)
		if coins_seen and stunned_seen:
			break
	check(coins_seen, "picked some coins")
	check(stunned_seen, "got caught at least once")
	check(player.inventory.count("coins") > 0, "coins in the pack")
	check(player.hp >= 1, "a cuff never kills")


func test_stunned_players_cannot_attack() -> void:
	var sim := _make_sim()
	var dummy := sim.add_combatant(50)
	dummy.position = Vector3(61, 0, 0)
	dummy.can_fight = false
	_player(sim).stunned_until = sim.tick + 10
	sim.queue_attack(PLAYER, 50)
	var events := _run(sim, 5)
	check(not events.any(func(e): return e["type"] == "hit" and e["attacker"] == PLAYER), "no attacks while stunned")


func test_better_thieves_get_caught_less() -> void:
	var stall := ContentDB.stall("cloth_stall")
	check(Thieving.caught_chance(50, stall) < Thieving.caught_chance(12, stall), "level helps")
	var mark := ContentDB.mark("merchant")
	check(Thieving.pickpocket_chance(60, mark) > Thieving.pickpocket_chance(18, mark), "level helps pickpocketing")


func _box_sim(level := 60) -> Simulation:
	var sim := _make_sim()
	sim.thieving.add_strongbox(1, "warehouse_strongbox", Vector3(61, 0, 1))
	_player(sim).skills.xp["thieving"] = _player(sim).skills.xp_for_level(level)
	_player(sim).max_hp = 50
	_player(sim).hp = 50
	return sim


func _crack(sim: Simulation) -> Array:
	sim.queue_item_action(PLAYER, "crack", {"strongbox": 1})
	return _run(sim, Thieving.strongbox_data("warehouse_strongbox")["crack_ticks"] + 2)


func test_a_strongbox_needs_a_lockpick_and_the_level() -> void:
	var sim := _box_sim()
	var events := _crack(sim)
	check(events.any(func(e): return e["type"] == "message" and "lockpick" in e["text"]), "needs a pick")
	sim = _box_sim(10)
	sim.give_item(PLAYER, "lockpick", 5, "test", [])
	events = _crack(sim)
	check(events.any(func(e): return e["type"] == "message" and "Thieving 30" in e["text"]), "needs Thieving 30")


func test_cracking_takes_time_then_pays_out_and_empties_the_box() -> void:
	var sim := _box_sim(99)
	sim.give_item(PLAYER, "lockpick", 20, "test", [])
	var emptied := false
	for attempt in 20:
		sim.queue_item_action(PLAYER, "crack", {"strongbox": 1})
		var started := sim.step()
		check(not started.any(func(e): return e["type"] == "strongbox_emptied"), "not cracked on the first tick")
		var events := _run(sim, 8)
		if events.any(func(e): return e["type"] == "strongbox_emptied"):
			emptied = true
			break
	check(emptied, "cracked it")
	check(_player(sim).skills.xp["thieving"] > _player(sim).skills.xp_for_level(99), "thieving xp")
	check(sim.thieving.strongboxes[1]["empty_until"] > sim.tick, "empty for a while")
	var again := _crack(sim)
	check(again.any(func(e): return e["type"] == "message" and "emptied" in e["text"]), "nothing left to take")


func test_a_sprung_trap_hurts_and_can_snap_the_pick() -> void:
	var trapped := 0
	var snapped := 0
	for seed in 30:
		var sim := _box_sim(30)
		sim.rng.seed = seed
		sim.give_item(PLAYER, "lockpick", 5, "test", [])
		var events := _crack(sim)
		if events.any(func(e): return e["type"] == "hit" and e["target"] == PLAYER):
			trapped += 1
			check(_player(sim).hp < 50 and _player(sim).hp >= 1, "hurt, never killed")
			if _player(sim).inventory.count("lockpick") == 4:
				snapped += 1
	check(trapped > 0 and trapped < 30, "traps spring sometimes (%d / 30)" % trapped)
	check(snapped > 0 and snapped <= trapped, "picks snap sometimes (%d)" % snapped)
