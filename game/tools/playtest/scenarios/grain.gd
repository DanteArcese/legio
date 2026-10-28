extends "res://tools/playtest/scenario.gd"
## Grain: sow seed wheat in a grain field south of the fort, grind wheat
## at the quern by the fields, and bake bread on the pond's campfire.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.skills.xp["farming"] = me.skills.xp_for_level(10)
	me.skills.xp["cooking"] = me.skills.xp_for_level(10)
	driver().sim.give_item(PLAYER, "trowel", 1, "test", [])
	driver().sim.give_item(PLAYER, "wheat_seed", 3, "test", [])
	driver().sim.give_item(PLAYER, "wheat", 2, "test", [])
	var field: Node3D = main.get_node("Farm/GrainField1")
	await route_to(field.global_position + Vector3(0, 0, -2.4), 0.6, 120.0)
	_choose(field, "Plant seed wheat")
	await _wait_until(func(): return field.crop == "wheat", 20.0)
	expect(field.crop == "wheat", "sowed wheat in the grain field")
	await shot("field")

	var quern: Node3D = main.get_node("Farm/Quern")
	await route_to(quern.global_position + Vector3(-1.4, 0, 0), 0.5, 60.0)
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "mill", "recipe": "flour", "count": 2})
	await action_done()
	expect(me.inventory.count("flour") == 2, "ground two pots of flour (%d)" % me.inventory.count("flour"))
	await shot("quern")

	var loaves: int = me.inventory.count("bread")
	var fire := _nearest_fire()
	await route_to(fire.global_position + Vector3(1.4, 0, 0), 0.4, 60.0)
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "cook", "recipe": "bread", "count": 2})
	await action_done()
	expect(me.inventory.count("bread") - loaves + me.inventory.count("burnt_food") == 2, "baked the flour")


func _nearest_fire() -> Node3D:
	var best: Node3D = null
	for station in get_tree().get_nodes_in_group("stations"):
		if station.kind == "fire" and (best == null or station.global_position.distance_to(player().global_position) < best.global_position.distance_to(player().global_position)):
			best = station
	return best


func _choose(node: Node, prefix: String) -> void:
	var options: Array = WorldMenu.options_for(player(), node).filter(func(o): return o[0].begins_with(prefix))
	expect(options.size() >= 1, "%s offers: %s (%s)" % [node.name, prefix, WorldMenu.options_for(player(), node).map(func(o): return o[0])])
	if not options.is_empty():
		options[0][1].call()


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
