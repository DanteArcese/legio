extends "res://tools/playtest/scenario.gd"
## F8 opens the note box and pauses; Enter saves the note with where the
## player is; the pause menu's "Leave a note" opens the same box for
## controller players, and Esc cancels without saving.

const NOTES := "user://playtest_feedback.md"


func run() -> void:
	await seconds(0.3)
	var note: Node = main.get_node("FeedbackNote")
	note.path = NOTES
	if FileAccess.file_exists(NOTES):
		DirAccess.remove_absolute(NOTES)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F8
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(3)
	expect(note.is_open() and get_tree().paused, "F8 opens the box and pauses")
	await shot("note_box")
	var edit: LineEdit = note._edit
	edit.text = "the smith is hard to find"
	edit.text_submitted.emit(edit.text)
	await _frames(3)
	expect(not note.is_open() and not get_tree().paused, "Enter saves, closes and unpauses")
	var text := FileAccess.get_file_as_string(NOTES)
	expect("the smith is hard to find" in text, "the note is saved")
	expect("Castra Ferrea" in text and "combat" in text, "with the region and context (%s)" % text)

	var menu: Node = main.get_node("PauseMenu")
	await press("pause_menu")
	await _frames(3)
	var button := _find_button(menu, "Leave a note (F8)")
	expect(button != null, "the pause menu offers a note")
	button.pressed.emit()
	await _frames(3)
	expect(note.is_open() and not menu.is_open() and get_tree().paused, "the menu hands over to the note box")
	await press("ui_cancel")
	await _frames(3)
	expect(not note.is_open() and not get_tree().paused, "Esc cancels and unpauses")
	expect(FileAccess.get_file_as_string(NOTES).count("## ") == 1, "nothing saved on cancel")
	DirAccess.remove_absolute(NOTES)


func _find_button(root: Node, text: String) -> Button:
	for child in root.find_children("*", "Button", true, false):
		if child.text == text:
			return child
	return null


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
