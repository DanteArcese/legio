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


## Presses and releases a controller button, the way a real pad does: every
## action bound to it sees the press, not just one.
func press_joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().physics_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().physics_frame


## Holds the left stick so the player walks toward a world position.
## If it stops making progress (snagged on something), it sidesteps briefly.
## Returns once within tolerance or after timeout seconds.
func walk_to(target: Vector3, tolerance := 0.5, timeout := 30.0) -> bool:
	var frames := ceili(timeout * Engine.physics_ticks_per_second)
	var last_check := player().global_position
	var sidestep_frames := 0
	var sidestep_sign := 1.0
	for i in frames:
		var offset := (target - player().global_position) * Vector3(1, 0, 1)
		if offset.length() <= tolerance:
			set_stick(Vector2.ZERO)
			return true
		var direction := offset.normalized()
		if sidestep_frames > 0:
			sidestep_frames -= 1
			direction = direction.cross(Vector3.UP) * sidestep_sign
		elif i % 60 == 59:
			if player().global_position.distance_to(last_check) < 0.3:
				sidestep_frames = 30
				sidestep_sign = -sidestep_sign
			last_check = player().global_position
		var yaw: float = main.get_node("CameraRig").global_rotation.y
		var local := direction.rotated(Vector3.UP, -yaw)
		set_stick(Vector2(local.x, local.z))
		await get_tree().physics_frame
	set_stick(Vector2.ZERO)
	return false


## Castra Ferrea's gates (just outside) and the matching points inside.
const GATES_OUTSIDE := [Vector3(0, 0, -22), Vector3(22, 0, 0), Vector3(0, 0, 22)]
const GATES_INSIDE := [Vector3(0, 0, -17), Vector3(17, 0, 0), Vector3(0, 0, 17)]
const TOWN_HALF_SIZE := 20.0


static func inside_town(position: Vector3) -> bool:
	return absf(position.x) < TOWN_HALF_SIZE and absf(position.z) < TOWN_HALF_SIZE


## Like walk_to, but goes through the best gate when the trip crosses the
## town walls. (Bots only; players steer themselves.)
func route_to(target: Vector3, tolerance := 0.5, timeout := 60.0) -> bool:
	var from := player().global_position
	if inside_town(from) != inside_town(target):
		var best := 0
		for i in GATES_OUTSIDE.size():
			var cost_i: float = from.distance_to(GATES_OUTSIDE[i]) + GATES_OUTSIDE[i].distance_to(target)
			var cost_best: float = from.distance_to(GATES_OUTSIDE[best]) + GATES_OUTSIDE[best].distance_to(target)
			if cost_i < cost_best:
				best = i
		var first: Vector3 = GATES_INSIDE[best] if inside_town(from) else GATES_OUTSIDE[best]
		var second: Vector3 = GATES_OUTSIDE[best] if inside_town(from) else GATES_INSIDE[best]
		await walk_to(first, 0.8, timeout)
		await walk_to(second, 0.8, timeout)
	return await walk_to(target, tolerance, timeout)


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


## Waits for the player's queued skilling action to start (commands apply
## on the next tick, up to 0.6 s away) and then to finish.
func action_done(timeout := 120.0) -> void:
	var me: RefCounted = driver().sim.get_combatant(1)
	for i in 30:
		if not me.skill_action.is_empty():
			break
		await seconds(0.1)
	var frames := ceili(timeout * Engine.physics_ticks_per_second)
	while not me.skill_action.is_empty() and frames > 0:
		await get_tree().physics_frame
		frames -= 1
