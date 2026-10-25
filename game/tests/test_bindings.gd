extends "res://tests/test_case.gd"

const Bindings := preload("res://scripts/input/bindings.gd")


func test_every_action_has_keyboard_or_mouse_and_gamepad_binding() -> void:
	Bindings.apply()
	for action in Bindings.DEFAULTS:
		var has_desktop := false
		var has_gamepad := false
		for event in InputMap.action_get_events(action):
			has_desktop = has_desktop or event is InputEventKey or event is InputEventMouseButton
			has_gamepad = has_gamepad or event is InputEventJoypadButton or event is InputEventJoypadMotion
		check(has_desktop, "%s has no keyboard/mouse binding" % action)
		check(has_gamepad, "%s has no gamepad binding" % action)


func test_no_input_is_bound_to_two_actions() -> void:
	var seen := {}
	for action in Bindings.DEFAULTS:
		for spec in Bindings.DEFAULTS[action]:
			var key := str(spec)
			check(not seen.has(key), "%s bound to both %s and %s" % [key, seen.get(key), action])
			seen[key] = action


func test_apply_is_idempotent() -> void:
	Bindings.apply()
	Bindings.apply()
	check_eq(InputMap.action_get_events("interact").size(), Bindings.DEFAULTS["interact"].size(), "interact events")


func test_stick_actions_respond_to_joypad_motion() -> void:
	Bindings.apply()
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_Y
	motion.axis_value = -0.8
	check(motion.is_action_pressed("move_forward"), "left stick up should map to move_forward")
	check(not motion.is_action_pressed("move_back"), "left stick up should not map to move_back")
