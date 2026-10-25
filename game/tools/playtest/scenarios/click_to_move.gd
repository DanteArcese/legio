extends "res://tools/playtest/scenario.gd"
## Mouse controls and pathfinding: clicking the ground walks there, walking
## out of town follows the navigation mesh through a gate, clicking a rat
## attacks it, and auto-approach paths around the walls to a boar outside.

const PLAYER := 1


func run() -> void:
	await seconds(0.3) # let the navigation map sync
	var camera := get_viewport().get_camera_3d()

	# A mouse click on the ground a few metres ahead. Headless Godot doesn't
	# deliver mouse events, so call click() there; rendered runs use a real event.
	var spot := Vector3(-3, 0, -3)
	if DisplayServer.get_name() == "headless":
		player().click(camera.unproject_position(spot))
	else:
		await _click_at(camera.unproject_position(spot))
	expect(player().destination != null, "clicking the ground sets a destination")
	await _wait_until(func(): return player().destination == null, 10.0)
	expect(_flat_distance(player().global_position, spot) < 0.8, "walked to the clicked spot")

	# Out through the walls to the quarry along the navigation mesh.
	player().walk_to(Vector3(26, 0, 1))
	var start: int = driver().sim.tick
	await _wait_until(func(): return player().destination == null, 40.0)
	expect(_flat_distance(player().global_position, Vector3(26, 0, 1)) < 0.8, "pathed out of town to the quarry")
	metric("seconds_to_quarry", snappedf((driver().sim.tick - start) * 0.6, 0.1))

	# Clicking a monster attacks it. Look straight down so nothing is in the way.
	var rat := _entity("rat")
	await _teleport(rat.body().global_position + Vector3(0, 1, -2))
	var rig: Node3D = main.get_node("CameraRig")
	rig._pitch = deg_to_rad(-80.0)
	rig._apply_rotation()
	await seconds(0.2)
	player().click(camera.unproject_position(rat.body().global_position + Vector3(0, 0.4, 0)))
	await seconds(1.0)
	expect(driver().sim.get_combatant(PLAYER).target_id == rat.entity_id, "clicking a rat targets it")

	# Auto-approach to a target outside the walls goes around them.
	driver().sim.queue_stop(PLAYER)
	await _teleport(Vector3(0, 1, 2))
	var boar := _entity("wild_boar")
	driver().sim.get_combatant(PLAYER).bonuses["defence"] = 500 # survive the walk
	driver().sim.queue_attack(PLAYER, boar.entity_id)
	await _wait_until(func(): return count_events("hit", {"attacker": PLAYER, "target": boar.entity_id}) > 0, 60.0)
	expect(count_events("hit", {"attacker": PLAYER, "target": boar.entity_id}) > 0, "auto-approach reached a boar outside the walls")

	# Clicking the bank chest walks over and opens the bank.
	driver().sim.queue_stop(PLAYER)
	await _teleport(Vector3(-6, 1, -4))
	var chest: Node3D = main.get_node("BankChest")
	player().click(camera.unproject_position(chest.global_position))
	await _wait_until(func(): return main.get_node("GameUi").is_bank_open(), 15.0)
	expect(main.get_node("GameUi").is_bank_open(), "clicking the bank chest opens the bank")
	await shot("bank_by_click")


func _teleport(position: Vector3) -> void:
	player().destination = null
	player().global_position = position
	await seconds(0.3)


func _click_at(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.global_position = position
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().physics_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().physics_frame


func _entity(monster_id: String) -> Node:
	for entity in get_tree().get_nodes_in_group("sim_entities"):
		if entity.monster_id == monster_id and entity.combatant.is_alive():
			return entity
	return null


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
