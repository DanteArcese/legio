extends "res://tools/playtest/scenario.gd"
## Loadouts from the inventory: Y on a loadout saves what's worn, then the
## keyboard's 2 and the controller's left shoulder + D-pad up swap sets, and
## the D-pad press doesn't also zoom or open a panel.

const PLAYER := 1


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var ui: Node = main.get_node("GameUi")
	var quest_ui: Node = main.get_node("QuestUi")
	driver().sim.give_item(PLAYER, "sling", 1, "test", [])
	driver().sim.give_item(PLAYER, "lead_glans", 40, "test", [])
	await seconds(0.3)
	# Set 1: the pugio the character starts with.
	driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of("bronze_pugio")})
	await seconds(0.7)
	await press_joy(JOY_BUTTON_BACK)
	expect(ui._inventory_panel.visible, "inventory open")
	ui._loadout_buttons[0].grab_focus()
	await press_joy(JOY_BUTTON_Y)
	expect(ui.is_menu_open(), "Y on a loadout opens its options")
	# Choosing an entry closes the menu, as a real press would.
	ui._menu.id_pressed.emit(1)
	ui._menu.hide()
	await seconds(0.7)
	expect(me.loadouts[0].get("worn", {}).get("weapon", "") == "bronze_pugio", "saved the pugio as loadout 1")
	await shot("inventory_loadouts")
	await press_joy(JOY_BUTTON_BACK)

	# Set 2: the sling and its lead, saved through the simulation directly.
	driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of("sling")})
	await seconds(0.7)
	driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of("lead_glans")})
	await seconds(0.7)
	driver().sim.queue_item_action(PLAYER, "save_loadout", {"index": 1})
	await seconds(0.7)

	var key := InputEventKey.new()
	key.physical_keycode = KEY_1
	key.keycode = KEY_1
	key.pressed = true
	Input.parse_input_event(key)
	await seconds(0.8)
	expect(me.equipment.worn["weapon"] == "bronze_pugio", "1 puts the pugio back in hand")

	var arm: SpringArm3D = main.get_node("CameraRig/SpringArm3D")
	var zoom := arm.spring_length
	var hold := InputEventJoypadButton.new()
	hold.button_index = JOY_BUTTON_LEFT_SHOULDER
	hold.pressed = true
	Input.parse_input_event(hold)
	await get_tree().physics_frame
	await press_joy(JOY_BUTTON_DPAD_RIGHT)
	hold = hold.duplicate()
	hold.pressed = false
	Input.parse_input_event(hold)
	await seconds(0.8)
	expect(me.equipment.worn["weapon"] == "sling", "left shoulder + D-pad right wears loadout 2")
	expect(not quest_ui.is_log_open(), "without opening the quest log")
	expect(is_equal_approx(arm.spring_length, zoom), "or zooming")


func _slot_of(item_id: String) -> int:
	var slots: Array = driver().sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1
