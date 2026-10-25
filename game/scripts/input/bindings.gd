extends RefCounted
## Default input bindings for keyboard/mouse and gamepad.
##
## Bindings live in code rather than project.godot so they are readable,
## testable, and easy to make rebindable later. Every action has both a
## keyboard/mouse binding and a gamepad binding.

const STICK_DEADZONE := 0.2

## action name -> list of binding specs.
## Spec forms: ["key", Key], ["mouse", MouseButton],
## ["joy_button", JoyButton], ["joy_axis", JoyAxis, direction].
const DEFAULTS := {
	"move_forward": [["key", KEY_W], ["joy_axis", JOY_AXIS_LEFT_Y, -1.0]],
	"move_back": [["key", KEY_S], ["joy_axis", JOY_AXIS_LEFT_Y, 1.0]],
	"move_left": [["key", KEY_A], ["joy_axis", JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [["key", KEY_D], ["joy_axis", JOY_AXIS_LEFT_X, 1.0]],
	"camera_left": [["key", KEY_LEFT], ["joy_axis", JOY_AXIS_RIGHT_X, -1.0]],
	"camera_right": [["key", KEY_RIGHT], ["joy_axis", JOY_AXIS_RIGHT_X, 1.0]],
	"camera_up": [["key", KEY_UP], ["joy_axis", JOY_AXIS_RIGHT_Y, -1.0]],
	"camera_down": [["key", KEY_DOWN], ["joy_axis", JOY_AXIS_RIGHT_Y, 1.0]],
	"camera_zoom_in": [["mouse", MOUSE_BUTTON_WHEEL_UP], ["joy_button", JOY_BUTTON_DPAD_UP]],
	"camera_zoom_out": [["mouse", MOUSE_BUTTON_WHEEL_DOWN], ["joy_button", JOY_BUTTON_DPAD_DOWN]],
	# Left-click is handled by click-to-move in player.gd, not bound here.
	"interact": [["key", KEY_E], ["joy_button", JOY_BUTTON_A]],
	"context_menu": [["mouse", MOUSE_BUTTON_RIGHT], ["joy_button", JOY_BUTTON_Y]],
	"target_next": [["key", KEY_TAB], ["joy_button", JOY_BUTTON_RIGHT_SHOULDER]],
	"target_prev": [["key", KEY_Q], ["joy_button", JOY_BUTTON_LEFT_SHOULDER]],
	"combat_style": [["key", KEY_C], ["joy_button", JOY_BUTTON_X]],
	"run_toggle": [["key", KEY_R], ["joy_button", JOY_BUTTON_LEFT_STICK]],
	"inventory": [["key", KEY_I], ["joy_button", JOY_BUTTON_BACK]],
	"pause_menu": [["key", KEY_ESCAPE], ["joy_button", JOY_BUTTON_START]],
}


## Registers every default action with the InputMap, replacing existing events.
static func apply() -> void:
	for action in DEFAULTS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, STICK_DEADZONE)
		for spec in DEFAULTS[action]:
			InputMap.action_add_event(action, make_event(spec))


static func make_event(spec: Array) -> InputEvent:
	match spec[0]:
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = spec[1]
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = spec[1]
			return mouse
		"joy_button":
			var button := InputEventJoypadButton.new()
			button.button_index = spec[1]
			return button
		"joy_axis":
			var axis := InputEventJoypadMotion.new()
			axis.axis = spec[1]
			axis.axis_value = spec[2]
			return axis
	push_error("Unknown binding spec: %s" % [spec])
	return null
