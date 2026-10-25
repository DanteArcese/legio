extends "res://tools/playtest/scenario.gd"
## Visits each area of Castra Ferrea and takes a screenshot, for reviewing
## the layout and visuals with --render. Headless, it just checks that the
## key places exist and are reachable on foot from spawn.

const STOPS := [
	["spawn", Vector3(0, 1, 2), 0.0],
	["bank", Vector3(-9, 1, -6), 0.6],
	["smithy", Vector3(10, 1, -5), 0.0],
	["quarry", Vector3(24, 1, 2), -1.2],
	["woods", Vector3(0, 1, -28), 0.0],
	["fields", Vector3(0, 1, 26), 3.14],
	["overview", Vector3(0, 1, 0), 0.8],
]


func run() -> void:
	var rig: Node3D = main.get_node("CameraRig")
	for stop in STOPS:
		player().global_position = stop[1]
		rig._yaw = stop[2]
		rig._apply_rotation()
		if stop[0] == "overview":
			rig._pitch = deg_to_rad(-70.0)
			rig._apply_rotation()
			rig.get_node("SpringArm3D").spring_length = 24.0
		await seconds(0.5)
		await shot(stop[0])
	# Reachability: walk from spawn through the east gate to the quarry.
	player().global_position = Vector3(0, 1, 2)
	await seconds(0.2)
	expect(await walk_to(Vector3(19, 0, 0), 0.6, 20.0), "reached the east gate")
	expect(await walk_to(Vector3(26, 0, -1), 0.6, 20.0), "reached the quarry")
