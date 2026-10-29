extends "res://tests/test_case.gd"
## The F8 note: its Markdown format and appending to the notes file.

const FeedbackNote := preload("res://scripts/ui/feedback_note.gd")
const TEST_PATH := "user://test_feedback.md"


func test_note_has_heading_text_and_context() -> void:
	var note := FeedbackNote.format_note("  the bank button is tiny  ", {
		"time": "2026-10-29 08:00:00 UTC", "region": "Castra Ferrea",
		"position": Vector3(12.4, 1.0, -7.4), "hp": "9/10", "combat": 3,
		"target": "rat", "task": "rat x4",
		"levels": {"attack": 2, "strength": 1, "vitality": 10},
	})
	check(note.begins_with("## 2026-10-29 08:00:00 UTC — Castra Ferrea\n\nthe bank button is tiny\n\n"), "heading and trimmed text (%s)" % note)
	check("at (12, 1, -7), hp 9/10, combat 3, target rat, task rat x4" in note, "facts line")
	check("levels: attack 2, vitality 10" in note, "trained skills only")
	check(not "strength" in note, "level-1 skills left out")


func test_empty_note_still_records_where() -> void:
	var note := FeedbackNote.format_note("", {"time": "t"})
	check_eq(note, "## t\n\n(no text)\n\n\n", "a bare note")


func test_save_appends() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	var box = FeedbackNote.new()
	box.path = TEST_PATH
	box.save("first")
	box.save("second")
	var text := FileAccess.get_file_as_string(TEST_PATH)
	check("first" in text and "second" in text, "both notes kept (%s)" % text)
	check(text.find("first") < text.find("second"), "in order")
	box.free()
	DirAccess.remove_absolute(TEST_PATH)
