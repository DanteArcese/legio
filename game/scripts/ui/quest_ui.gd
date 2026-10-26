extends CanvasLayer
## The dialogue box for NPC conversations, and the quest log (J / D-pad right).
##
## Dialogue arrives from the sim as a list of lines. Interact (E / A), a
## click, or the Continue button moves to the next line. This layer sits
## after the player in the tree, so it sees input first and keeps Interact
## from also talking to the NPC again.

const ContentDB := preload("res://scripts/content/content_db.gd")
const Quests := preload("res://scripts/sim/quests.gd")

@export var driver: Node
@export var player: Node

var _dialogue_panel: PanelContainer
var _speaker: Label
var _line: Label
var _continue: Button
var _lines: Array = []
var _line_index := 0
var _log_panel: PanelContainer
var _log_text: RichTextLabel


func _ready() -> void:
	_build_dialogue()
	_build_log()
	driver.sim_event.connect(_on_sim_event)


func _unhandled_input(event: InputEvent) -> void:
	if is_dialogue_open() and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		advance()
		get_viewport().set_input_as_handled()
	elif is_dialogue_open() and event.is_action_pressed("ui_cancel"):
		close_dialogue()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quest_log"):
		toggle_log()
		get_viewport().set_input_as_handled()


func is_dialogue_open() -> bool:
	return _dialogue_panel.visible


func show_dialogue(speaker: String, lines: Array) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_line_index = 0
	_speaker.text = speaker
	_dialogue_panel.visible = true
	_show_line()


## Next line, or close after the last one.
func advance() -> void:
	_line_index += 1
	if _line_index >= _lines.size():
		close_dialogue()
	else:
		_show_line()


func close_dialogue() -> void:
	_dialogue_panel.visible = false
	_lines = []


func is_log_open() -> bool:
	return _log_panel.visible


func toggle_log() -> void:
	_log_panel.visible = not _log_panel.visible
	if _log_panel.visible:
		_refresh_log()


## The quest log as plain text, for tests.
func log_text() -> String:
	return _log_text.get_parsed_text()


func _on_sim_event(event: Dictionary) -> void:
	if event.get("id") != player.get_node("SimEntity").entity_id:
		return
	match event["type"]:
		"dialogue":
			show_dialogue(event["speaker"], event["lines"])
		"quest_started", "quest_step", "quest_progress", "quest_complete":
			if _log_panel.visible:
				_refresh_log.call_deferred()


func _show_line() -> void:
	_line.text = _lines[_line_index]
	_continue.text = "Continue  (E / A)" if _line_index < _lines.size() - 1 else "Close  (E / A)"


func _refresh_log() -> void:
	var combatant: RefCounted = player.get_node("SimEntity").combatant
	if combatant == null:
		return
	var text := ""
	var rank := Quests.rank(combatant)
	if not rank.is_empty():
		text += "[i]Rank: %s[/i]\n\n" % rank
	for quest_id in ContentDB.quest_ids():
		var quest := ContentDB.quest(quest_id)
		match Quests.status(combatant, quest_id):
			"done":
				text += "[color=#8fd18f][b]%s[/b]  (complete)[/color]\n" % quest["name"]
				if quest["rewards"].has("unlocks"):
					text += "    Unlocked: %s\n" % quest["rewards"]["unlocks"]
			"in_progress":
				var step := Quests.current_step(combatant, quest_id)
				var state: Dictionary = combatant.quests[quest_id]
				var progress := ""
				if step.has("count"):
					progress = "  (%d / %d)" % [state["progress"], step["count"]]
				elif step.get("kind") == "deliver":
					var parts := []
					for entry in step["items"]:
						var have: int = mini(combatant.inventory.count(entry["item"]), entry["quantity"])
						parts.append("%s %d/%d" % [ContentDB.item(entry["item"])["name"].to_lower(), have, entry["quantity"]])
					progress = "  (%s)" % ", ".join(parts)
				text += "[color=#f0d070][b]%s[/b][/color]\n    %s%s\n" % [quest["name"], step["log"], progress]
			_:
				var giver: String = ContentDB.npc(quest["giver"]).get("name", "someone")
				text += "[color=#d08080][b]%s[/b][/color]\n    %s Speak to %s to begin.\n" % [quest["name"], quest["summary"], giver]
		text += "\n"
	_log_text.text = text


func _build_dialogue() -> void:
	_dialogue_panel = PanelContainer.new()
	# Top centre: clear of the HUD at the bottom, and of the player in the middle.
	_dialogue_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_dialogue_panel.custom_minimum_size = Vector2(680, 0)
	_dialogue_panel.position += Vector2(-340, 165)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.94)
	style.border_color = Color(0.6, 0.48, 0.28)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	_dialogue_panel.add_theme_stylebox_override("panel", style)
	add_child(_dialogue_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_dialogue_panel.add_child(column)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 22)
	_speaker.add_theme_color_override("font_color", Color(0.95, 0.8, 0.5))
	column.add_child(_speaker)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(640, 60)
	_line.add_theme_font_size_override("font_size", 20)
	column.add_child(_line)
	_continue = Button.new()
	_continue.focus_mode = Control.FOCUS_NONE
	_continue.size_flags_horizontal = Control.SIZE_SHRINK_END
	_continue.pressed.connect(advance)
	column.add_child(_continue)
	_dialogue_panel.visible = false


func _build_log() -> void:
	_log_panel = PanelContainer.new()
	_log_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_log_panel.position += Vector2(30, -220)
	add_child(_log_panel)
	var column := VBoxContainer.new()
	_log_panel.add_child(column)
	var heading := Label.new()
	heading.text = "Quests  (J / D-pad right)"
	heading.add_theme_font_size_override("font_size", 20)
	column.add_child(heading)
	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = true
	_log_text.fit_content = true
	_log_text.custom_minimum_size = Vector2(420, 120)
	column.add_child(_log_text)
	_log_panel.visible = false
