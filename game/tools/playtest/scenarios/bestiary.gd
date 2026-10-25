extends "res://tools/playtest/scenario.gd"
## Lines up one of every monster (display only, not simulated) in an open
## field and takes close-up screenshots, for reviewing models with --render.

const ContentDB := preload("res://scripts/content/content_db.gd")
const MonsterScene := preload("res://scenes/monster.tscn")
const ROW_START := Vector3(36, 0, 30)


func run() -> void:
	var ids: Array = ContentDB.data()["monsters"].keys()
	var showcase := Node3D.new()
	main.add_child(showcase)
	for i in ids.size():
		var monster: Node3D = MonsterScene.instantiate()
		monster.monster_id = ids[i]
		monster.get_node("SimEntity").remove_from_group("sim_entities")
		showcase.add_child(monster)
		monster.global_position = ROW_START + Vector3(i * 2.6, 0, 0)
		# Heads point -Z; turn them three-quarters toward the camera (+Z).
		monster.rotation.y = PI - 0.5
		expect(monster.get_child_count() > 3, "%s has a model" % ids[i])
	player().global_position = ROW_START + Vector3(ids.size() * 1.3 - 1.3, 1, 5)
	var rig: Node3D = main.get_node("CameraRig")
	rig._yaw = 0.0
	rig._pitch = deg_to_rad(-22.0)
	rig._apply_rotation()
	rig.get_node("SpringArm3D").spring_length = 11.0
	await seconds(0.5)
	await shot("lineup")
	# Walk the player past the camera to see the walk cycle.
	set_stick(Vector2(1, 0))
	await seconds(0.4)
	await shot("walking")
	set_stick(Vector2.ZERO)
