extends "res://tools/playtest/scenario.gd"
## Portus Salis: take the south-west road to the coast, hear the surf, walk
## out along the pier and harpoon a tuna, and take the road home again.

const PLAYER := 1


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.skills.xp["fishing"] = me.skills.xp_for_level(45)
	driver().sim.give_item(PLAYER, "harpoon", 1, "test", [])
	var road: Node3D = main.get_node("RoadToPortus")
	await route_to(Vector3(-16, 0, 24), 1.0, 90.0)
	await walk_to(road.global_position + Vector3(0, 0, -1.6), 0.6, 60.0)
	player().travel(road)
	await _wait_until(func(): return player().global_position.x < -250.0, 20.0)
	expect(player().global_position.x < -250.0, "the road leads to the coast")
	await seconds(3.0)
	expect(main.get_node("Sound").zone == "coast", "surf and gulls at the coast (%s)" % main.get_node("Sound").zone)
	await shot("arrival")

	for waypoint in [Vector3(-300, 0, -20), Vector3(-300, 0, 4), Vector3(-300, 0, 14), Vector3(-300, 0, 29.3)]:
		await walk_to(waypoint, 0.6, 60.0)
		if waypoint.z == 4:
			main.get_node("CameraRig")._orbit(PI, 0.0)
			await seconds(0.4)
			await shot("harbour")
			main.get_node("CameraRig")._orbit(-PI, 0.0)
	expect(player().global_position.z > 28.0 and player().global_position.y > 0.3, "out at the end of the pier, above the water")
	await shot("pier")
	var spot: Node3D = main.get_node("PortusSalis/TunaSpot")
	player().fish(spot)
	await _wait_until(func(): return me.inventory.count("raw_tuna") > 0, 90.0)
	expect(me.inventory.count("raw_tuna") > 0, "harpooned a tuna")

	var crabs := get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.monster_id == "rock_crab")
	var harpies := get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.monster_id == "harpy")
	expect(crabs.size() == 4 and harpies.size() == 3, "crabs on the beach and harpies on the rocks")

	for waypoint in [Vector3(-300, 0, 14), Vector3(-300, 0, -20), Vector3(-300, 0, -44)]:
		await walk_to(waypoint, 0.6, 60.0)
	player().travel(main.get_node("PortusSalis/RoadToFort"))
	await _wait_until(func(): return player().global_position.x > -50.0, 20.0)
	expect(player().global_position.x > -50.0, "and the road leads home")


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
