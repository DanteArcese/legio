extends CanvasLayer
## The skills panel (K / left trigger): every skill's level in a grid, with
## the focused or hovered skill's XP and XP to the next level underneath.
## D-pad or arrow keys move between skills.

const Skills := preload("res://scripts/sim/skills.gd")

const COLUMNS := 3

@export var driver: Node
@export var player: Node

var _panel: PanelContainer
var _buttons := {}
var _total: Label
var _detail: Label


func _ready() -> void:
	_build()
	driver.ticked.connect(func(_tick): if is_open(): _refresh())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skills_panel"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_refresh()
		_buttons[Skills.NAMES[0]].grab_focus()
	else:
		var focused := get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()


## "Mining 12" etc., for tests.
func button_text(skill: String) -> String:
	return _buttons[skill].text


func detail_text() -> String:
	return _detail.text


func _skills() -> RefCounted:
	var combatant: RefCounted = player.get_node("SimEntity").combatant
	return combatant.skills if combatant else null


func _refresh() -> void:
	var skills := _skills()
	if skills == null:
		return
	var total := 0
	for skill in Skills.NAMES:
		var level: int = skills.level(skill)
		total += level
		_buttons[skill].text = "%s  %d" % [skill.capitalize(), level]
	_total.text = "Total level %d     Combat level %d" % [total, skills.combat_level()]
	var focused := get_viewport().gui_get_focus_owner()
	for skill in _buttons:
		if _buttons[skill] == focused:
			_show_detail(skill)


func _show_detail(skill: String) -> void:
	var skills := _skills()
	if skills == null:
		return
	var xp: float = skills.xp[skill]
	var level: int = skills.level(skill)
	if level >= Skills.MAX_LEVEL:
		_detail.text = "%s: %s XP (max level)" % [skill.capitalize(), _thousands(xp)]
	else:
		var remaining := Skills.xp_for_level(level + 1) - xp
		_detail.text = "%s: %s XP, %s to level %d" % [skill.capitalize(), _thousands(xp), _thousands(remaining), level + 1]


static func _thousands(value: float) -> String:
	var digits := str(floori(value))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return out


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.position -= Vector2(270, 200)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.08, 0.93)
	style.set_content_margin_all(14)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	var heading := Label.new()
	heading.text = "Skills  (K / left trigger)"
	heading.add_theme_font_size_override("font_size", 20)
	column.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	column.add_child(grid)
	for skill in Skills.NAMES:
		var button := Button.new()
		button.custom_minimum_size = Vector2(170, 38)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_entered.connect(_show_detail.bind(skill))
		button.mouse_entered.connect(_show_detail.bind(skill))
		grid.add_child(button)
		_buttons[skill] = button
	_total = Label.new()
	column.add_child(_total)
	_detail = Label.new()
	_detail.custom_minimum_size = Vector2(520, 0)
	column.add_child(_detail)
	_panel.visible = false
