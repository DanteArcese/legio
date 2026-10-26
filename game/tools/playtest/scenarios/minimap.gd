extends "res://tools/playtest/scenario.gd"
## The minimap: nearby things get dots, the map turns with the camera so
## what's ahead of the camera is at the top, and it follows the player out
## of town.


func run() -> void:
	await seconds(0.5)
	var minimap: Node = main.get_node("Minimap")
	var dots: Array = minimap.dots()
	expect(dots.size() > 3, "dots for the forum's NPCs and stations (%d)" % dots.size())
	var dummy: Node3D = main.get_node("TrainingDummy")
	var at: Vector2 = minimap.to_map(dummy.global_position)
	var centre := Vector2(minimap.SIZE, minimap.SIZE) / 2.0
	# Turn the camera and the same spot moves around the map.
	main.get_node("CameraRig")._orbit(PI / 2.0, 0.0)
	await seconds(0.2)
	var turned: Vector2 = minimap.to_map(dummy.global_position)
	expect(absf(at.distance_to(centre) - turned.distance_to(centre)) < 1.0, "turning keeps distances")
	expect(at.distance_to(turned) > 5.0, "turning moves the dot (%s -> %s)" % [at, turned])
	# Straight ahead of the camera is the top of the map.
	var rig: Node3D = main.get_node("CameraRig")
	var forward := -rig.global_transform.basis.z
	forward.y = 0.0
	var ahead: Vector2 = minimap.to_map(player().global_position + forward.normalized() * 10.0)
	expect(ahead.y < centre.y - 20.0 and absf(ahead.x - centre.x) < 2.0, "ahead is up (%s)" % ahead)
	await shot("town")
	await route_to(Vector3(0, 0, -32), 2.0, 90.0)
	await seconds(0.3)
	var reds: Array = minimap.dots().filter(func(d): return d["color"] == minimap.MONSTER)
	expect(not reds.is_empty(), "wolves show as red dots in the woods")
	await shot("woods")
