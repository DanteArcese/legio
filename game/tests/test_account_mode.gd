extends "res://tests/test_case.gd"
## Leaving the Solitarius path: once, for good. Hardcore: one life.

const Simulation := preload("res://scripts/sim/simulation.gd")

const PLAYER := 1


func test_a_solitarius_can_leave_but_not_return() -> void:
	var sim := Simulation.new(1)
	var player := sim.add_player(PLAYER)
	player.account_mode = "solitarius"
	sim.queue_item_action(PLAYER, "leave_solitarius")
	var events := sim.step()
	check_eq(player.account_mode, "standard", "left")
	check(events.any(func(e): return e["type"] == "account_mode_changed"), "event")
	sim.queue_item_action(PLAYER, "leave_solitarius")
	events = sim.step()
	check(not events.any(func(e): return e["type"] == "account_mode_changed"), "nothing more to leave")


func test_hardcore_keeps_solitarius_rules() -> void:
	var sim := Simulation.new(1)
	var player := sim.add_player(PLAYER)
	player.account_mode = "hardcore"
	check(player.is_solitarius(), "hardcore is a Solitarius")
	check_eq(sim.give_item(PLAYER, "coins", 10, "market", []), 0, "no market")


func test_a_hardcore_death_makes_a_plain_solitarius() -> void:
	var sim := Simulation.new(1)
	var player := sim.add_player(PLAYER)
	player.account_mode = "hardcore"
	player.hp = 0
	var events: Array[Dictionary] = []
	sim.kill(player, events)
	check_eq(player.account_mode, "solitarius", "status lost")
	check(events.any(func(e): return e["type"] == "account_mode_changed" and e["mode"] == "solitarius"), "event")
	check(events.any(func(e): return e["type"] == "message" and "one life" in e["text"]), "told")
	events.clear()
	sim.kill(player, events)
	check_eq(player.account_mode, "solitarius", "a second death changes nothing")


func test_hardcore_can_leave_for_standard() -> void:
	var sim := Simulation.new(1)
	var player := sim.add_player(PLAYER)
	player.account_mode = "hardcore"
	sim.queue_item_action(PLAYER, "leave_solitarius")
	sim.step()
	check_eq(player.account_mode, "standard", "left")
