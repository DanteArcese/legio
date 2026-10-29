extends "res://tools/playtest/scenario.gd"
## Plays the menus with real controller buttons (several actions share a
## button, so a press can leak): the D-pad at a menu's edge must not also
## zoom the camera or open the quest log or blessings, and the bank's
## category filter narrows it without typing.

const PLAYER := 1


func run() -> void:
	await seconds(0.5)
	var ui: Node = main.get_node("GameUi")
	var quest_ui: Node = main.get_node("QuestUi")
	var arm: SpringArm3D = main.get_node("CameraRig/SpringArm3D")
	var zoom := arm.spring_length

	await press_joy(JOY_BUTTON_BACK)
	expect(ui._inventory_panel.visible, "Back opens the inventory")
	for i in 8:
		await press_joy(JOY_BUTTON_DPAD_RIGHT)
	expect(not quest_ui.is_log_open(), "D-pad right at the inventory's edge doesn't open the quest log")
	for i in 8:
		await press_joy(JOY_BUTTON_DPAD_UP)
	expect(is_equal_approx(arm.spring_length, zoom), "D-pad up at the top doesn't zoom the camera")
	for i in 8:
		await press_joy(JOY_BUTTON_DPAD_DOWN)
	expect(is_equal_approx(arm.spring_length, zoom), "nor D-pad down at the bottom")
	for i in 8:
		await press_joy(JOY_BUTTON_DPAD_LEFT)
	expect(not ui.is_blessings_open(), "D-pad left at the edge doesn't open the blessings")
	await press_joy(JOY_BUTTON_BACK)
	expect(not ui._inventory_panel.visible, "Back closes it")
	await press_joy(JOY_BUTTON_DPAD_UP)
	expect(arm.spring_length < zoom, "with nothing open, D-pad up zooms in")

	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for item in ["copper_ore", "bread", "bronze_gladius", "bronze_axe"]:
		me.bank.add(item, 1)
	ui.open_bank()
	await seconds(0.3)
	var filter: Button = ui._bank_filter
	filter.grab_focus()
	await press_joy(JOY_BUTTON_A)
	expect(ui._bank_category == "gear", "A on the filter shows gear")
	expect(ui._bank_grid.get_child_count() == 1, "just the gladius (%d)" % ui._bank_grid.get_child_count())
	await press_joy(JOY_BUTTON_A)
	await press_joy(JOY_BUTTON_A)
	expect(ui._bank_category == "food", "then food")
	await shot("bank_food")
	expect(ui.is_bank_open(), "pressing A in the bank doesn't close it")
	var me_special: bool = me.special_armed
	await press_joy(JOY_BUTTON_B)
	expect(not ui.is_bank_open(), "B closes the bank")
	expect(me.special_armed == me_special, "without arming a special attack")

	var menu: Node = main.get_node("PauseMenu")
	await press_joy(JOY_BUTTON_START)
	expect(menu.is_open(), "Start pauses")
	await press_joy(JOY_BUTTON_DPAD_DOWN)
	await press_joy(JOY_BUTTON_DPAD_DOWN)
	var settings: Node = main.get_node("GraphicsSettings")
	var hidden: bool = settings.hide_roofs()
	await press_joy(JOY_BUTTON_A)
	expect(settings.hide_roofs() != hidden, "A presses a pause-menu button (Hide roofs)")
	await press_joy(JOY_BUTTON_B)
	expect(not menu.is_open() and not get_tree().paused, "B backs out and unpauses")

