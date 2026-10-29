extends "res://tools/playtest/scenario.gd"
## The cursus publicus: walk up to the fort's waystation to unlock it, visit
## the limes station, then ride the post back from the stationmaster's menu.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	driver().sim.give_item(PLAYER, "coins", 200, "test", [])
	var fort: Node3D = main.get_node("Waystation_castra")
	expect(await route_to(fort.global_position + Vector3(0, 0, 3), 1.0, 90.0), "out to the fort's waystation")
	await seconds(1.0)
	expect(me.waystations.has("castra"), "known at the fort's station")
	await shot("station")
	var limes: Node3D = main.get_node("Waystation_limes")
	player().destination = null
	player().global_position = limes.global_position + Vector3(5, 1, -3)
	await seconds(1.0)
	var reached := await walk_to(limes.global_position + Vector3(0, 0, -2), 0.8, 20.0)
	await shot("limes")
	expect(reached, "up to the limes station (at %s, station %s)" % [player().global_position.round(), limes.global_position.round()])
	await seconds(0.5)
	expect(me.waystations.has("limes"), "known at the limes")
	player().global_position = player().global_position + Vector3(0, 0, -1)
	await seconds(0.5)
	var coins: int = me.inventory.count("coins")
	var options: Array = WorldMenu.options_for(player(), limes)
	var ride: Array = options.filter(func(o): return o[0].begins_with("Ride the post to Castra Ferrea"))
	expect(ride.size() == 1, "the post back to the fort is offered (%s)" % [options.map(func(o): return o[0])])
	if ride.size() == 1:
		ride[0][1].call()
	await seconds(2.0)
	for i in 60:
		if player().global_position.distance_to(fort.global_position) < 6.0:
			break
		await seconds(0.25)
	expect(player().global_position.distance_to(fort.global_position) < 6.0, "rode back to the fort")
	expect(me.inventory.count("coins") == coins - 20, "for 20 denarii (%d)" % me.inventory.count("coins"))
