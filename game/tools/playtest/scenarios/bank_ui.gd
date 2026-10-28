extends "res://tools/playtest/scenario.gd"
## Drives the bank and inventory UI with controller-style inputs: walk to
## the bank chest, interact, deposit with A, navigate with the D-pad,
## withdraw, search and sort, close with B, and open the inventory.

const PLAYER := 1


func run() -> void:
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var ui: Node = main.get_node("GameUi")
	var chest: Vector3 = main.get_node("BankChest").global_position
	expect(await walk_to(chest + Vector3(0, 0, 1.6), 0.4), "reached the bank chest")
	await press("interact")
	await seconds(0.2)
	expect(ui.is_bank_open(), "interact opens the bank")
	await shot("bank_open")

	# The bank starts empty, so focus starts on inventory slot 0 (the pugio).
	await press("ui_accept")
	await seconds(1.0)
	expect(me.bank.count("bronze_pugio") == 1, "A deposits the focused item")
	await press("ui_right")
	await press("ui_accept")
	await seconds(1.0)
	expect(me.bank.count("bread") == 4, "D-pad right then A deposits all the bread")
	expect(me.inventory.count("bread") == 0, "bread left the inventory")
	await shot("after_deposits")

	driver().sim.queue_item_action(PLAYER, "withdraw", {"item": "bread", "quantity": 2})
	await seconds(1.0)
	expect(me.inventory.count("bread") == 2, "withdrew 2 bread")

	ui._bank_search.text = "pug"
	ui._bank_search.text_changed.emit("pug")
	await seconds(0.2)
	expect(ui._bank_grid.get_child_count() == 1, "searching \"pug\" shows just the pugio (%d)" % ui._bank_grid.get_child_count())
	var start := player().global_position
	ui._bank_search.grab_focus()
	Input.action_press("move_forward")
	await seconds(0.5)
	Input.action_release("move_forward")
	expect(player().global_position.distance_to(start) < 0.1, "typing in the search box doesn't walk")
	await shot("bank_search")
	ui._bank_search.text = ""
	ui._bank_search.text_changed.emit("")
	ui._bank_sort.pressed.emit()
	await seconds(0.2)
	expect(ui._bank_grid.get_child(0).text.begins_with("Bread"), "sorted by name, bread first (%s)" % ui._bank_grid.get_child(0).text)
	ui._bank_grid.get_child(0).grab_focus()

	await press("ui_cancel")
	await seconds(0.2)
	expect(not ui.is_bank_open(), "B closes the bank")
	await press("inventory")
	await seconds(0.2)
	await shot("inventory")
	expect(ui.get_node_or_null(".") != null, "ui alive")
	metric("bank_items", me.bank.slots.filter(func(s): return s != null).size())
