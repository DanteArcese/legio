extends RefCounted
## The controls list shown in the pause menu: what each action does, and its
## keyboard/mouse and controller bindings, read from bindings.gd so the list
## never goes out of date.

const Bindings := preload("res://scripts/input/bindings.gd")

## [what it does, actions bound to it (their bindings are joined)].
const ROWS := [
	["Move", ["move_forward", "move_left", "move_back", "move_right"]],
	["Turn and tilt the camera", ["camera_left", "camera_right", "camera_up", "camera_down"]],
	["Zoom", ["camera_zoom_in", "camera_zoom_out"]],
	["Interact with the nearest thing", ["interact"]],
	["Options for what's under the cursor or nearby", ["context_menu"]],
	["Next / previous target", ["target_next", "target_prev"]],
	["Combat style", ["combat_style"]],
	["Special attack", ["special_attack"]],
	["Run on / off", ["run_toggle"]],
	["Inventory and equipment", ["inventory"]],
	["Quest log", ["quest_log"]],
	["Skills", ["skills_panel"]],
	["Tabularium (collection log)", ["collection_log"]],
	["Blessings (Pietas)", ["pietas_menu"]],
	["World map", ["world_map"]],
	["Hide roofs", ["toggle_roofs"]],
	["Pause menu", ["pause_menu"]],
	["Choose in a menu", ["ui_accept"]],
	["Back out of a menu", ["ui_cancel"]],
]
const JOY_BUTTONS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_START: "Start", JOY_BUTTON_MISC1: "Share",
	JOY_BUTTON_LEFT_SHOULDER: "Left shoulder", JOY_BUTTON_RIGHT_SHOULDER: "Right shoulder",
	JOY_BUTTON_LEFT_STICK: "Left stick click", JOY_BUTTON_RIGHT_STICK: "Right stick click",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}
const JOY_AXES := {
	JOY_AXIS_LEFT_X: "Left stick", JOY_AXIS_LEFT_Y: "Left stick", JOY_AXIS_RIGHT_X: "Right stick",
	JOY_AXIS_RIGHT_Y: "Right stick", JOY_AXIS_TRIGGER_LEFT: "Left trigger", JOY_AXIS_TRIGGER_RIGHT: "Right trigger",
}
const MOUSE_BUTTONS := {
	MOUSE_BUTTON_LEFT: "Left click", MOUSE_BUTTON_RIGHT: "Right click",
	MOUSE_BUTTON_WHEEL_UP: "Wheel", MOUSE_BUTTON_WHEEL_DOWN: "Wheel",
}


## Each row as [what it does, keyboard and mouse, controller].
static func rows() -> Array:
	var out := []
	for row in ROWS:
		var keys := []
		var pads := []
		for action in row[1]:
			for spec in Bindings.DEFAULTS[action]:
				var name := spec_name(spec)
				var list: Array = pads if spec[0].begins_with("joy") else keys
				if not list.has(name):
					list.append(name)
		var keyboard := " ".join(keys) if row[1].size() > 2 else " / ".join(keys)
		if keyboard == "Left Right Up Down":
			keyboard = "Arrow keys"
		out.append([row[0], keyboard, " / ".join(pads)])
	return out


static func spec_name(spec: Array) -> String:
	match spec[0]:
		"key":
			return OS.get_keycode_string(spec[1])
		"mouse":
			return MOUSE_BUTTONS.get(spec[1], "Mouse")
		"joy_button":
			return JOY_BUTTONS.get(spec[1], "Button %d" % spec[1])
		"joy_axis":
			return JOY_AXES.get(spec[1], "Axis %d" % spec[1])
	return "?"
