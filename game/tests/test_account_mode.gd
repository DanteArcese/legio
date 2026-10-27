extends "res://tests/test_case.gd"
## Leaving the Solitarius path: once, for good.

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
