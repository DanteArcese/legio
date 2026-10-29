extends CanvasLayer
## Esc / Start: pauses the game and offers Resume, the graphics preset,
## Hide roofs, volume sliders, leaving the Solitarius path (for those on
## it), leaving a note (F8), and Quit. Fully controller-navigable
## (left and right adjust a focused slider).

@export var settings: Node
@export var game_ui: Node
@export var sound: Node
@export var skills_ui: Node
## The F8 note box, also opened from here for controller players.
@export var feedback: Node

const ControlsText := preload("res://scripts/input/controls_text.gd")

var _panel: PanelContainer
## The controls page, shown in place of the menu.
var _controls: PanelContainer
var _controls_back: Button
var _graphics_button: Button
var _roofs_button: Button
var _display_button: Button
## Shown to Solitarius players; the first press asks, the second gives it up.
var _leave_button: Button
var _leave_armed := false
## Set once the player has chosen to leave, before the simulation applies it.
var _left := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(360, 0)
	_panel.position -= Vector2(180, 220)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.08, 0.95)
	style.set_content_margin_all(18)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	column.add_child(_button("Resume", close))
	_graphics_button = _button("", func():
		settings.cycle_preset()
		_refresh())
	column.add_child(_graphics_button)
	_roofs_button = _button("", func():
		settings.set_hide_roofs(not settings.hide_roofs())
		_refresh())
	column.add_child(_roofs_button)
	_display_button = _button("", func():
		settings.set_fullscreen(not settings.fullscreen)
		_refresh())
	column.add_child(_display_button)
	if sound:
		for bus in sound.BUSES:
			column.add_child(_volume_row(bus))
	_leave_button = _button("", _leave_solitarius)
	column.add_child(_leave_button)
	if feedback:
		column.add_child(_button("Leave a note (F8)", func():
			close()
			feedback.open()))
	column.add_child(_button("Controls", show_controls))
	column.add_child(_button("Quit", func(): get_tree().quit()))
	_panel.visible = false
	_build_controls(style)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause_menu"):
		return
	# Esc also closes the bank; let that happen first.
	if game_ui and game_ui.is_bank_open():
		return
	# Esc also closes the skills panel.
	if skills_ui and skills_ui.is_open():
		return
	if is_controls_open():
		_hide_controls()
	elif is_open():
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


func open() -> void:
	_refresh()
	_panel.visible = true
	get_tree().paused = true
	(_panel.get_child(0).get_child(1) as Button).grab_focus()


func close() -> void:
	_panel.visible = false
	_controls.visible = false
	_leave_armed = false
	get_tree().paused = false
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()


func is_open() -> bool:
	return _panel.visible or _controls.visible


func is_controls_open() -> bool:
	return _controls.visible


func show_controls() -> void:
	_panel.visible = false
	_controls.visible = true
	_controls_back.grab_focus()


func _hide_controls() -> void:
	_controls.visible = false
	_panel.visible = true
	(_panel.get_child(0).get_child(1) as Button).grab_focus()


## Every action, with its keyboard/mouse and controller binding.
func _build_controls(style: StyleBox) -> void:
	_controls = PanelContainer.new()
	_controls.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_controls.position -= Vector2(330, 300)
	_controls.add_theme_stylebox_override("panel", style)
	add_child(_controls)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_controls.add_child(column)
	var title := Label.new()
	title.text = "Controls"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	column.add_child(grid)
	for heading in ["", "Keyboard and mouse", "Controller"]:
		var label := Label.new()
		label.text = heading
		label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.5))
		grid.add_child(label)
	for row in ControlsText.rows():
		for cell in row:
			var label := Label.new()
			label.text = cell
			label.add_theme_font_size_override("font_size", 16)
			grid.add_child(label)
	_controls_back = _button("Back", _hide_controls)
	column.add_child(_controls_back)
	_controls.visible = false


func _refresh() -> void:
	_graphics_button.text = "Graphics: %s" % settings.preset.capitalize()
	_roofs_button.text = "Hide roofs: %s" % ("On" if settings.hide_roofs() else "Off")
	_display_button.text = "Display: %s (F11)" % ("Fullscreen" if settings.fullscreen else "Windowed")
	var combatant := _combatant()
	_leave_button.visible = combatant != null and combatant.is_solitarius() and not _left
	_leave_button.text = "Really give it up? Press again" if _leave_armed else "Leave the Solitarius path"


func _leave_solitarius() -> void:
	if not _leave_armed:
		_leave_armed = true
		_refresh()
		return
	_leave_armed = false
	var player := get_tree().get_first_node_in_group("player")
	# Applied on the next tick, once the game resumes; hidden until then.
	player.sim_driver.sim.queue_item_action(player.get_node("SimEntity").entity_id, "leave_solitarius")
	_left = true
	_refresh()


func _combatant() -> RefCounted:
	var player := get_tree().get_first_node_in_group("player")
	return player.get_node("SimEntity").combatant if player else null


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 44)
	button.pressed.connect(action)
	return button


func _volume_row(bus: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Sound" if bus == "Master" else bus
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = "%sVolume" % bus
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.1
	slider.value = sound.volume(bus)
	slider.custom_minimum_size = Vector2(210, 32)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(value): sound.set_volume(bus, value))
	row.add_child(slider)
	return row
