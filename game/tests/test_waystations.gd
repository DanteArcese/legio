extends "res://tests/test_case.gd"
## The cursus publicus: waystations unlock when you walk up, and the post
## takes you between unlocked ones for a fee; unlocks are saved.

const Simulation := preload("res://scripts/sim/simulation.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")

const PLAYER := 1
const FORT := Vector3(0, 0, 0)
const PORT := Vector3(-300, 0, 0)


func _make_sim() -> Simulation:
	var sim := Simulation.new(2)
	sim.add_player(PLAYER)
	sim.waystations.add("castra", FORT)
	sim.waystations.add("portus", PORT)
	sim.give_item(PLAYER, "coins", 100, "test", [])
	return sim


func test_unlock_then_ride() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.position = FORT + Vector3(2, 0, 0)
	sim.step()
	check(player.waystations.has("castra"), "the fort's station unlocked by walking up")
	sim.queue_item_action(PLAYER, "waystation_travel", {"to": "portus"})
	var events := sim.step()
	check(player.position.distance_to(FORT) < 5.0, "not to a station you've never visited")
	check(events.any(func(e): return e["type"] == "message" and "never been" in e["text"]), "told why")
	player.position = PORT
	sim.step()
	player.position = FORT + Vector3(1, 0, 0)
	sim.queue_item_action(PLAYER, "waystation_travel", {"to": "portus"})
	sim.step()
	check(player.position.distance_to(PORT) < 3.0, "rode the post to Portus Salis")
	check_eq(player.inventory.count("coins"), 75, "for 25 denarii")


func test_unlocks_are_saved() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.position = PORT
	sim.step()
	var text := SaveGame.to_json(SaveGame.capture(sim, PLAYER))
	var fresh := Simulation.new(2)
	fresh.add_player(PLAYER)
	check(SaveGame.restore(fresh, PLAYER, SaveGame.from_json(text)), "restored")
	check_eq(fresh.get_combatant(PLAYER).waystations, ["portus"], "Portus still known")
