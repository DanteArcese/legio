extends "res://tools/playtest/scenario.gd"
## Stand behind a house so it's between the camera and the player: the
## house and its roof should fade, then return once the player walks clear.
## Also checks the hide-roofs toggle and that the camera no longer bumps
## into buildings.

func run() -> void:
	await seconds(0.3)
	var fader: Node = main.get_node("OcclusionFader")
	var house: Node3D = main.get_node("CastraFerrea/Buildings/HouseA")
	var rig: Node3D = main.get_node("CameraRig")
	# House A spans z 11.5..15.5; with the camera south of the player
	# (yaw 0 looks north), standing just north of it puts it in the way.
	player().global_position = Vector3(12, 1, 9.5)
	rig._yaw = 0.0
	rig._pitch = deg_to_rad(-30.0)
	rig._apply_rotation()
	await seconds(1.0)
	expect(fader.occluders().has(house), "the house is between camera and player")
	expect(fader.is_faded(house), "the house fades")
	var arm: SpringArm3D = rig.get_node("SpringArm3D")
	expect(arm.get_hit_length() > arm.spring_length - 0.5, "camera passes through the house instead of zooming in")
	await shot("faded_house")

	player().global_position = Vector3(2, 1, 6)
	await seconds(1.5)
	expect(not fader.is_faded(house), "the house returns once out of the way")

	await press("toggle_roofs")
	await seconds(0.1)
	var roof: Node3D = main.get_node("CastraFerrea/Buildings/HouseARoof")
	expect(not roof.visible, "H / R3 hides roofs")
	await shot("roofs_hidden")
	await press("toggle_roofs")
	expect(roof.visible, "and shows them again")
