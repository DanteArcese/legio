extends Node
## Base class for playtest scenarios. Override run() as a coroutine that
## drives the game through the helpers below, records metrics, and states
## expectations. The runner writes results and exits non-zero on failure.

var main: Node
var metrics := {}
var failures: PackedStringArray = []
var out_dir := ""
var events: Array[Dictionary] = []


func run() -> void:
	pass


func player() -> CharacterBody3D:
	return main.get_node("Player")


func driver() -> Node:
	return main.get_node("SimDriver")


func seconds(duration: float) -> void:
	var frames := ceili(duration * Engine.physics_ticks_per_second)
	for i in frames:
		await get_tree().physics_frame


func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().physics_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)


## Holds the left stick so the player walks toward a world position.
## Returns once within tolerance or after timeout seconds.
func walk_to(target: Vector3, tolerance := 0.5, timeout := 30.0) -> bool:
	var frames := ceili(timeout * Engine.physics_ticks_per_second)
	for i in frames:
		var offset := (target - player().global_position) * Vector3(1, 0, 1)
		if offset.length() <= tolerance:
			set_stick(Vector2.ZERO)
			return true
		var yaw: float = main.get_node("CameraRig").global_rotation.y
		var local := offset.normalized().rotated(Vector3.UP, -yaw)
		set_stick(Vector2(local.x, local.z))
		await get_tree().physics_frame
	set_stick(Vector2.ZERO)
	return false


func set_stick(value: Vector2) -> void:
	_set_axis("move_left", "move_right", value.x)
	_set_axis("move_forward", "move_back", value.y)


func _set_axis(negative: String, positive: String, value: float) -> void:
	Input.action_release(negative)
	Input.action_release(positive)
	if value < -0.01:
		Input.action_press(negative, -value)
	elif value > 0.01:
		Input.action_press(positive, value)


func metric(name: String, value: Variant) -> void:
	metrics[name] = value


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func count_events(type: String, filter := {}) -> int:
	var count := 0
	for event in events:
		if event["type"] != type:
			continue
		var matches := true
		for key in filter:
			matches = matches and event.get(key) == filter[key]
		if matches:
			count += 1
	return count


## Saves a screenshot when rendering is available (skipped in headless runs).
func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_dir.path_join("%s.png" % name))
