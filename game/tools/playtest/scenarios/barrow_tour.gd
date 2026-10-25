extends "res://tools/playtest/scenario.gd"
## Screenshots of each barrow room for reviewing the dungeon art with
## --render. Headless, it checks that the dresser built walls and floors.

const STOPS := [["entry", Vector3(150, 1, 2.5), 0.0], ["halls", Vector3(150, 1, -18), 0.0], ["depths", Vector3(22, 1, -28), -1.4]]


func run() -> void:
	await seconds(0.3)
	var barrow: Node3D = main.get_node("Barrow")
	expect(barrow.get_node_or_null("FloorTiles") != null and barrow.get_node("FloorTiles").get_child_count() > 10, "floor tiles laid")
	expect(barrow.get_node("Walls").get_child(0).get_child_count() > 2, "wall pieces added")
	var rig: Node3D = main.get_node("CameraRig")
	for stop in STOPS:
		var at: Vector3 = stop[1]
		if at.x < 100:
			at.x += 150
		player().global_position = at
		rig._yaw = stop[2]
		rig._apply_rotation()
		await seconds(0.6)
		await shot(stop[0])
