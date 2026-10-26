extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/sim/simulation.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")
const DeathRules := preload("res://scripts/sim/death_rules.gd")

const PLAYER := 1


func _make_sim(seed := 1) -> Simulation:
	var sim := Simulation.new(seed)
	sim.add_player(PLAYER, Vector3.ZERO)
	return sim


## XP drops in Hunter until the leveret turns up (1 in 800 each).
func _hunt_for_leveret(sim: Simulation) -> Array:
	var player: RefCounted = sim.get_combatant(PLAYER)
	for i in 20000:
		var events: Array[Dictionary] = []
		sim.award_xp(player, "hunter", 1.0, events)
		if events.any(func(e): return e["type"] == "pet_drop"):
			return events
	return []


func test_a_skill_pet_follows_you() -> void:
	var sim := _make_sim()
	var events := _hunt_for_leveret(sim)
	check(not events.is_empty(), "the leveret turned up")
	var player: RefCounted = sim.get_combatant(PLAYER)
	check_eq(player.pet, "leveret", "and follows the player")
	check_eq(player.collection.get("leveret", 0), 1, "logged in the Tabularium")


func test_a_second_copy_is_not_given() -> void:
	var sim := _make_sim()
	_hunt_for_leveret(sim)
	var events := _hunt_for_leveret(sim)
	var player: RefCounted = sim.get_combatant(PLAYER)
	check(events.any(func(e): return e["type"] == "message" and "would have been followed" in e["text"]) or events.is_empty(), "no duplicate")
	check_eq(player.inventory.count("leveret"), 0, "nothing in the pack")


func test_pick_up_and_let_out() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.pet = "mole"
	sim.queue_item_action(PLAYER, "pickup_pet")
	sim.step()
	check_eq(player.pet, "", "picked up")
	check_eq(player.inventory.count("mole"), 1, "in the pack")
	sim.queue_item_action(PLAYER, "release_pet", {"slot": player.inventory.slots.find(player.inventory.slots.filter(func(s): return s != null and s["item"] == "mole")[0])})
	sim.step()
	check_eq(player.pet, "mole", "let out again")
	check_eq(player.inventory.count("mole"), 0, "out of the pack")


func test_only_one_follower() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.pet = "mole"
	sim.give_item(PLAYER, "magpie", 1, "test", [])
	sim.queue_item_action(PLAYER, "release_pet", {"slot": 0})
	var events := sim.step()
	check_eq(player.pet, "mole", "the mole stays out")
	check(events.any(func(e): return e["type"] == "message" and "already have a follower" in e["text"]), "told why")


func test_pets_are_never_lost_on_death() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	for item_id in ["iron_lorica", "iron_scutum", "iron_gladius", "magpie"]:
		sim.give_item(PLAYER, item_id, 1, "test", [])
	var split := DeathRules.split(player.inventory, player.equipment)
	check(split["kept_inventory"].any(func(e): return e["item"] == "magpie"), "the magpie is kept")
	check_eq(split["kept_inventory"].size(), 4, "as well as the 3 most valuable items")
	check(not split["lost"].any(func(e): return e["item"] == "magpie"), "never lost")


func test_pet_survives_a_save() -> void:
	var sim := _make_sim()
	sim.get_combatant(PLAYER).pet = "magpie"
	var data := SaveGame.from_json(SaveGame.to_json(SaveGame.capture(sim, PLAYER)))
	var other := _make_sim()
	SaveGame.restore(other, PLAYER, data)
	check_eq(other.get_combatant(PLAYER).pet, "magpie", "restored")
