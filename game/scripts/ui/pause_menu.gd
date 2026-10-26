extends CanvasLayer
## Esc / Start: pauses the game and offers Resume, the graphics preset,
## Hide roofs, volume sliders, and Quit. Fully controller-navigable
## (left and right adjust a focused slider).

@export var settings: Node
@export var game_ui: Node
@export var sound: Node
@export var skills_ui: Node

var _panel: PanelContainer
var _graphics_button: Button
var _roofs_button: Button


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
	if sound:
		for bus in sound.BUSES:
			column.add_child(_volume_row(bus))
	column.add_child(_button("Quit", func(): get_tree().quit()))
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause_menu"):
		return
	# Esc also closes the bank; let that happen first.
	if game_ui and game_ui.is_bank_open():
		return
	# Esc also closes the skills panel.
	if skills_ui and skills_ui.is_open():
		return
	if is_open():
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
	get_tree().paused = false
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()


func is_open() -> bool:
	return _panel.visible


func _refresh() -> void:
	_graphics_button.text = "Graphics: %s" % settings.preset.capitalize()
	_roofs_button.text = "Hide roofs: %s" % ("On" if settings.hide_roofs() else "Off")


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
