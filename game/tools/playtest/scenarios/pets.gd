extends "res://tools/playtest/scenario.gd"
## Pets: let a leveret out of the pack and it trots after you, keeping up on
## a walk; its menu picks it up again.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.5)
	var sim: RefCounted = driver().sim
	var me: RefCounted = sim.get_combatant(PLAYER)
	sim.give_item(PLAYER, "leveret", 1, "test", [])
	var slot: int = me.inventory.slots.find(me.inventory.slots.filter(func(s): return s != null and s["item"] == "leveret")[0])
	sim.queue_item_action(PLAYER, "release_pet", {"slot": slot})
	await seconds(1.0)
	var pets := get_tree().get_nodes_in_group("pets")
	expect(me.pet == "leveret" and pets.size() == 1, "the leveret is out")
	if pets.is_empty():
		return
	var pet: Node3D = pets[0]

	var start := player().global_position
	await walk_to(start + Vector3(8, 0, 0), 0.5, 15.0)
	await seconds(1.5)
	var gap := Vector2(pet.global_position.x - player().global_position.x, pet.global_position.z - player().global_position.z).length()
	metric("pet_gap", snappedf(gap, 0.01))
	expect(gap < 2.5, "it keeps up with the player (%.1f m behind)" % gap)
	await shot("pet")

	var options: Array = WorldMenu.options_for(player(), pet)
	expect(not options.is_empty() and options[0][0] == "Pick up leveret", "its menu offers to pick it up (%s)" % [options.map(func(o): return o[0])])
	if not options.is_empty():
		options[0][1].call()
	await seconds(1.5)
	expect(me.pet == "" and me.inventory.count("leveret") == 1, "picked up into the pack")
	expect(get_tree().get_nodes_in_group("pets").filter(func(p): return not p.is_queued_for_deletion()).is_empty(), "and it's gone from the world")
