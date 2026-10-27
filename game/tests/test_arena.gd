extends "res://tests/test_case.gd"
## Arena contracts: weaken a beast, net it alive, and the lanista pays.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Arena := preload("res://scripts/sim/arena.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")

const PLAYER := 1
const BOAR := 50


func _make_sim(hunter := 20) -> Simulation:
	var sim := Simulation.new(27)
	var player := sim.add_player(PLAYER)
	player.skills.xp["hunter"] = Skills.xp_for_level(hunter)
	sim.arena.set_lanista(Vector3(1, 0, 0))
	sim.give_item(PLAYER, "weighted_net", 3, "test", [])
	return sim


func _do(sim: Simulation, action: String, args := {}) -> Array:
	sim.queue_item_action(PLAYER, action, args)
	return sim.step()


func _messages(events: Array) -> String:
	return " | ".join(events.filter(func(e): return e["type"] == "message").map(func(e): return e["text"]))


func test_contracts_open_with_hunter_level() -> void:
	check(Arena.contracts_for(20).has("boars"), "boars at 20")
	check(not Arena.contracts_for(20).has("wolves"), "wolves need 25")
	check(Arena.contracts_for(60).has("basilisks"), "basilisks at 60")


func test_a_beast_must_be_weakened_before_netting() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	_do(sim, "take_arena", {"contract": "boars"})
	check_eq(player.arena_contract.get("remaining"), 5, "contract taken")
	var boar := sim.add_monster(BOAR, "wild_boar", Vector3(1, 0, 1))
	var events := _do(sim, "capture", {"target": BOAR})
	check(boar.is_alive(), "too lively")
	check("too lively" in _messages(events), "told why")
	check_eq(player.inventory.count("weighted_net"), 3, "net kept")
	boar.hp = 1
	events = _do(sim, "capture", {"target": BOAR})
	check(not boar.is_alive(), "netted")
	check(events.any(func(e): return e["type"] == "captured"), "captured event")
	check(not events.any(func(e): return e["type"] == "drop"), "no drops")
	check_eq(player.arena_contract["remaining"], 4, "one down")
	check_eq(player.inventory.count("weighted_net"), 2, "net used")
	check(player.skills.xp["hunter"] > Skills.xp_for_level(20), "Hunter XP")


func test_only_the_contract_beast_can_be_netted() -> void:
	var sim := _make_sim()
	_do(sim, "take_arena", {"contract": "boars"})
	var rat := sim.add_monster(BOAR, "rat", Vector3(1, 0, 1))
	rat.hp = 1
	var events := _do(sim, "capture", {"target": BOAR})
	check(rat.is_alive(), "not a rat")
	check("doesn't want" in _messages(events), "told why")


func test_the_lanista_pays_for_a_finished_contract() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	_do(sim, "take_arena", {"contract": "boars"})
	player.arena_contract["remaining"] = 0
	_do(sim, "hand_in_arena")
	check(player.arena_contract.is_empty(), "contract closed")
	check_eq(player.inventory.count("coins"), Arena.data()["contracts"]["boars"]["coins"], "paid")
	check_eq(player.arena_contracts_done, 1, "counted")


func test_the_contract_survives_a_save() -> void:
	var sim := _make_sim()
	_do(sim, "take_arena", {"contract": "boars"})
	sim.get_combatant(PLAYER).arena_contract["remaining"] = 2
	var text := SaveGame.to_json(SaveGame.capture(sim, PLAYER))
	var loaded := _make_sim()
	SaveGame.restore(loaded, PLAYER, SaveGame.from_json(text))
	check_eq(loaded.get_combatant(PLAYER).arena_contract, {"id": "boars", "remaining": 2}, "kept")
