extends "res://tools/playtest/scenario.gd"
## Region tasks in the quest log: chopping logs ticks one off, and the log
## lists every region's tasks under the quests.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	driver().sim.give_item(PLAYER, "logs", 1, "skilling", events)
	await seconds(0.3)
	expect(me.tasks_done.has("castra_ferrea/logs"), "chopping logs ticks a task off")
	var quest_ui: Node = main.get_node("QuestUi")
	await press("quest_log")
	await seconds(0.3)
	var text: String = quest_ui.log_text()
	expect("Region tasks" in text, "the log has a tasks section")
	expect("Castra Ferrea  (1 / 10" in text, "with the count (%s)" % text.substr(text.find("Castra Ferrea  ("), 30))
	quest_ui._log_text.scroll_to_line(quest_ui._log_text.get_line_count() - 30)
	await seconds(0.2)
	await shot("tasks")
	# The d-pad scrolls the open log on a controller, instead of zooming.
	var bar: ScrollBar = quest_ui._log_text.get_v_scroll_bar()
	bar.value = 0.0
	var zoom: float = main.get_node("CameraRig").get_node("SpringArm3D").spring_length
	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	Input.parse_input_event(down)
	await seconds(0.2)
	expect(bar.value > 0.0, "d-pad down scrolls the log (%s)" % bar.value)
	expect(is_equal_approx(main.get_node("CameraRig").get_node("SpringArm3D").spring_length, zoom), "and doesn't zoom")
	await press("quest_log")
