extends "res://tools/playtest/scenario.gd"
## A Solitarius gives up the path from the pause menu: the button asks
## once, then it's done, and it's gone from the menu.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var menu: Node = main.get_node("PauseMenu")
	menu.open()
	await get_tree().process_frame
	expect(not menu._leave_button.visible, "not offered on the usual path")
	menu.close()
	me.account_mode = "solitarius"
	menu.open()
	await get_tree().process_frame
	expect(menu._leave_button.visible, "offered to a Solitarius")
	menu._leave_button.pressed.emit()
	await get_tree().process_frame
	expect("Really" in menu._leave_button.text, "asks to be sure")
	expect(me.account_mode == "solitarius", "not yet")
	await shot("confirm")
	menu._leave_button.pressed.emit()
	await get_tree().process_frame
	expect(not menu._leave_button.visible, "gone from the menu")
	menu.close()
	await seconds(1.0)
	expect(me.account_mode == "standard", "left the path")
	expect(count_events("account_mode_changed", {"id": PLAYER}) == 1, "the simulation agrees")
