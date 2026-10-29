extends "res://tests/test_case.gd"

const Bindings := preload("res://scripts/input/bindings.gd")
const ControlsText := preload("res://scripts/input/controls_text.gd")


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
	# The menu actions (ui_*) share buttons with world actions on purpose:
	# A interacts in the world and presses a button in a menu.
	var seen := {}
	for action in Bindings.DEFAULTS:
		if action.begins_with("ui_"):
			continue
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


func test_every_action_is_on_the_controls_page() -> void:
	var listed := []
	for row in ControlsText.ROWS:
		listed.append_array(row[1])
	for action in Bindings.DEFAULTS:
		check(listed.has(action), "%s is listed" % action)


func test_controls_rows_name_both_bindings() -> void:
	for row in ControlsText.rows():
		check(not row[1].is_empty() and not row[2].is_empty(), "%s has keyboard and controller (%s)" % [row[0], row])
	var special: Array = ControlsText.rows().filter(func(r): return r[0] == "Special attack")[0]
	check_eq(special[1], "F", "keyboard")
	check_eq(special[2], "B", "controller")


func test_a_and_b_work_menus() -> void:
	Bindings.apply()
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	check(a.is_action_pressed("ui_accept") and a.is_action_pressed("interact"), "A presses menu buttons and interacts")
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	check(b.is_action_pressed("ui_cancel"), "B backs out of menus")
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	check(enter.is_action_pressed("ui_accept"), "Enter still works")
