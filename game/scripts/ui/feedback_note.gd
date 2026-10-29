extends CanvasLayer
## F8 (or "Leave a note" in the pause menu): a one-line box for writing down
## what you notice while playing. Each note is appended to user://feedback.md
## with where you were and what you were doing, so development sessions can
## read it back from the save folder and turn notes into issues.

const PATH := "user://feedback.md"

@export var world_map: Node
@export var driver: Node
## Where notes go; tests point this somewhere else.
@export var path := PATH

var _panel: PanelContainer
var _edit: LineEdit
## Whether opening paused the game, so closing only unpauses what it paused.
var _paused_here := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 11
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.position -= Vector2(280, 60)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.08, 0.95)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	var title := Label.new()
	title.text = "Leave a note for the developers"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)
	_edit = LineEdit.new()
	_edit.placeholder_text = "What did you notice? Enter saves, Esc cancels. (On a controller, A saves where you are.)"
	_edit.custom_minimum_size = Vector2(528, 40)
	_edit.text_submitted.connect(func(text: String): save(text); close())
	column.add_child(_edit)
	var where := Label.new()
	where.text = "Saved with where you are and what you're doing."
	where.add_theme_color_override("font_color", Color(0.7, 0.66, 0.58))
	column.add_child(where)
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F8 and not is_open():
		open()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# Esc would otherwise reach the pause menu.
	if is_open() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_edit.text = ""
	_panel.visible = true
	_paused_here = not get_tree().paused
	get_tree().paused = true
	_edit.grab_focus()


func close() -> void:
	_panel.visible = false
	_edit.release_focus()
	if _paused_here:
		get_tree().paused = false
	_paused_here = false


func is_open() -> bool:
	return _panel.visible


## Appends a note with the player's current context. Empty notes still
## record where the player was, which is worth something on a controller.
func save(text: String) -> void:
	var file: FileAccess
	if FileAccess.file_exists(path):
		file = FileAccess.open(path, FileAccess.READ_WRITE)
		file.seek_end()
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(format_note(text, context()))
	file.close()


## What the player is doing right now, for the note.
func context() -> Dictionary:
	var ctx := {"time": Time.get_datetime_string_from_system(true, true) + " UTC"}
	if not is_inside_tree():
		return ctx
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return ctx
	ctx["position"] = player.global_position
	if world_map:
		ctx["region"] = world_map.region_at(player.global_position)
	var combatant: RefCounted = player.get_node("SimEntity").combatant
	ctx["hp"] = "%d/%d" % [combatant.hp, combatant.max_hp]
	ctx["combat"] = combatant.combat_level()
	var levels := {}
	for skill in combatant.skills.NAMES:
		levels[skill] = combatant.level(skill)
	ctx["levels"] = levels
	if not combatant.slayer_task.is_empty():
		ctx["task"] = "%s x%d" % [combatant.slayer_task.get("monster", "?"), combatant.slayer_task.get("remaining", 0)]
	if driver and combatant.target_id >= 0:
		var target: RefCounted = driver.sim.get_combatant(combatant.target_id)
		if target:
			ctx["target"] = target.monster_id if target.monster_id != "" else "entity %d" % target.id
	return ctx


## One note as Markdown: a heading with the time and place, the text, and a
## line of context. Skills at level 1 are left out to keep it short.
static func format_note(text: String, ctx: Dictionary) -> String:
	var where: String = ctx.get("region", "")
	var heading := "## %s" % ctx.get("time", "")
	if where != "":
		heading += " — %s" % where
	var body := text.strip_edges() if text.strip_edges() != "" else "(no text)"
	var facts: Array[String] = []
	if ctx.has("position"):
		var p: Vector3 = ctx["position"]
		facts.append("at (%.0f, %.0f, %.0f)" % [p.x, p.y, p.z])
	if ctx.has("hp"):
		facts.append("hp %s" % ctx["hp"])
	if ctx.has("combat"):
		facts.append("combat %d" % ctx["combat"])
	if ctx.has("target"):
		facts.append("target %s" % ctx["target"])
	if ctx.has("task"):
		facts.append("task %s" % ctx["task"])
	var trained: Array[String] = []
	var levels: Dictionary = ctx.get("levels", {})
	for skill in levels:
		if levels[skill] > 1:
			trained.append("%s %d" % [skill, levels[skill]])
	var out := "%s\n\n%s\n\n" % [heading, body]
	if not facts.is_empty():
		out += "- %s\n" % ", ".join(facts)
	if not trained.is_empty():
		out += "- levels: %s\n" % ", ".join(trained)
	return out + "\n"
