extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/sim/simulation.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")

const PLAYER := 1


func _make_sim() -> Simulation:
	var sim := Simulation.new(5)
	sim.add_player(PLAYER, Vector3.ZERO)
	return sim


func test_skilling_and_quest_items_count() -> void:
	var sim := _make_sim()
	var events: Array[Dictionary] = []
	sim.give_item(PLAYER, "raw_tuna", 1, "skilling", events)
	sim.give_item(PLAYER, "raw_tuna", 2, "skilling", events)
	sim.give_item(PLAYER, "spatha", 1, "quest", events)
	var logged: Dictionary = sim.get_combatant(PLAYER).collection
	check_eq(logged, {"raw_tuna": 3, "spatha": 1}, "counted")
	check_eq(events.filter(func(e): return e["type"] == "collection_new").size(), 2, "each first one announced once")


func test_shops_and_starting_kit_do_not_count() -> void:
	var sim := _make_sim()
	sim.give_item(PLAYER, "spatha", 1, "shop", [])
	sim.give_starting_kit(PLAYER)
	check(sim.get_combatant(PLAYER).collection.is_empty(), "nothing logged")


func test_uncollectable_items_are_ignored() -> void:
	var sim := _make_sim()
	sim.give_item(PLAYER, "copper_ore", 1, "skilling", [])
	check(sim.get_combatant(PLAYER).collection.is_empty(), "copper ore is not on any page")


func test_monster_drops_count_for_the_killer() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.bonuses = {"attack": 5000, "strength": 5000, "defence": 0}
	var wolf := sim.add_monster(50, "wolf", Vector3(1, 0, 0))
	sim.queue_attack(PLAYER, 50)
	for i in 20:
		sim.step()
		if not wolf.is_alive():
			break
	check_eq(player.collection.get("wolf_pelt", 0), 1, "the wolf pelt is logged")


func test_collection_survives_a_save() -> void:
	var sim := _make_sim()
	sim.give_item(PLAYER, "fox_pelt", 4, "skilling", [])
	var data := SaveGame.from_json(SaveGame.to_json(SaveGame.capture(sim, PLAYER)))
	var other := _make_sim()
	SaveGame.restore(other, PLAYER, data)
	check_eq(other.get_combatant(PLAYER).collection, {"fox_pelt": 4}, "restored")
