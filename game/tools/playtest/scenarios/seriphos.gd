extends "res://tools/playtest/scenario.gd"
## Seriphos: no fare, no crossing; then pay the ferryman at Portus Salis's
## pier, sail to the island, buy olives from Nikias, visit the ruined
## temple of Athena, and sail home.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.inventory.remove("coins", me.inventory.count("coins"))
	var ferry: Node3D = main.get_node("PortusSalis/FerryToSeriphos")
	player().destination = null
	player().global_position = ferry.global_position + Vector3(0, 1, -2.0)
	await seconds(1.0)
	player().travel(ferry)
	await seconds(2.0)
	expect(player().global_position.z < 100.0, "no crossing without the fare")

	driver().sim.give_item(PLAYER, "coins", 100, "test", [])
	await seconds(0.3)
	player().travel(ferry)
	await _wait_until(func(): return player().global_position.z > 200.0, 20.0)
	expect(player().global_position.z > 200.0, "sailed to Seriphos")
	await seconds(1.0)
	expect(me.inventory.count("coins") == 75, "paid 25 denarii (%d left)" % me.inventory.count("coins"))
	expect(main.get_node("Sound").zone == "coast", "surf on the island (%s)" % main.get_node("Sound").zone)
	await shot("arrival")

	expect(await walk_to(Vector3(-300, 0, 284), 1.0, 40.0), "walked off the pier into town")
	var nikias: Node3D = main.get_node("Seriphos/Nikias")
	var olives: Array = WorldMenu.wares_for(player(), nikias).filter(func(o): return o[0].begins_with("Buy olives"))
	expect(olives.size() == 1, "Nikias sells olives")
	if olives.size() == 1:
		olives[0][1].call()
	await _wait_until(func(): return me.inventory.count("olives") > 0, 30.0)
	expect(me.inventory.count("olives") == 1, "bought olives")
	await shot("town")
	for waypoint in [Vector3(-300, 0, 298), Vector3(-278, 0, 305)]:
		expect(await walk_to(waypoint, 1.0, 40.0), "walked to %s" % waypoint)
	# Look east across the temple platform from its western edge.
	var rig: Node3D = main.get_node("CameraRig")
	rig._yaw = PI / 2.0
	rig._pitch = deg_to_rad(-25.0)
	rig._apply_rotation()
	rig.get_node("SpringArm3D").spring_length = 14.0
	await seconds(0.5)
	await shot("temple")

	var home: Node3D = main.get_node("Seriphos/FerryToPortus")
	player().destination = null
	player().global_position = home.global_position + Vector3(0, 1, 2.0)
	await seconds(1.0)
	player().travel(home)
	await _wait_until(func(): return player().global_position.z < 100.0, 20.0)
	expect(player().global_position.z < 100.0, "sailed home")


func _wait_until(condition: Callable, timeout: float) -> void:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await seconds(0.25)
		waited += 0.25
