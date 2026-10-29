extends "res://tests/test_case.gd"
## Return tablets: read one to be carried home; not in the arena.

const Simulation := preload("res://scripts/sim/simulation.gd")

const PLAYER := 1


func _make_sim() -> Simulation:
	var sim := Simulation.new(14)
	sim.add_player(PLAYER, Vector3(0, 0, -400))
	sim.give_item(PLAYER, "return_tablet_fort", 2, "test", [])
	return sim


func _read(sim: Simulation) -> Array:
	var slots: Array = sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == "return_tablet_fort":
			sim.queue_item_action(PLAYER, "read", {"slot": i})
			return sim.step()
	return []


func test_reading_a_tablet_carries_you_home() -> void:
	var sim := _make_sim()
	var events := _read(sim)
	var player: RefCounted = sim.get_combatant(PLAYER)
	check(player.position.distance_to(Vector3(2, 0, 3)) < 0.01, "home in Castra Ferrea")
	check_eq(player.inventory.count("return_tablet_fort"), 1, "one tablet used up")
	check(events.any(func(e): return e["type"] == "teleported"), "the world hears of it")


func test_not_in_the_arena() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.games = {"wave": 1, "alive": [], "spawned": [], "rest_until": 0, "earned": 0}
	_read(sim)
	check(player.position.distance_to(Vector3(0, 0, -400)) < 0.01, "stayed put")
	check_eq(player.inventory.count("return_tablet_fort"), 2, "tablet kept")
