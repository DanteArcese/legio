extends "res://tools/playtest/scenario.gd"
## Right-click and Y-button menus: examine a rat from its menu, open the bank
## from the controller menu, and take one item out of a mixed loot pile.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var ui: Node = main.get_node("GameUi")
	var camera := get_viewport().get_camera_3d()
	var rig: Node3D = main.get_node("CameraRig")

	# Right-click a rat, seen from above so nothing is in the way.
	var rat := _entity("rat")
	await _teleport(rat.body().global_position + Vector3(0, 1, -2.5))
	rig._pitch = deg_to_rad(-80.0)
	rig._apply_rotation()
	await seconds(0.2)
	player().open_menu_at(camera.unproject_position(rat.body().global_position + Vector3(0, 0.3, 0)))
	await seconds(0.1)
	expect(ui.is_menu_open(), "right-click opens a menu")
	expect(_menu_labels(ui).size() > 0 and _menu_labels(ui)[0].begins_with("Attack Rat"), "first option attacks (%s)" % [_menu_labels(ui)])
	await shot("rat_menu")
	await _choose(ui, "Examine Rat")
	expect(ui._message.text == "Fat from the town's grain stores.", "examine shows the rat's description")
	rig._pitch = deg_to_rad(-42.0)
	rig._apply_rotation()

	# Y at the bank chest: the nearest thing comes first.
	await _teleport(main.get_node("BankChest").global_position + Vector3(0, 0.6, 1.6))
	await press("context_menu")
	await seconds(0.1)
	expect(ui.is_menu_open(), "Y opens the nearby menu")
	expect(_menu_labels(ui)[0] == "Open bank", "bank first (%s)" % [_menu_labels(ui)])
	await press("ui_accept")
	await seconds(0.5)
	expect(ui.is_bank_open(), "choosing Open bank opens it")
	await press("ui_cancel")

	# A mixed pile: take only the coins.
	await _teleport(Vector3(-2, 1, 6))
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var coins_before: int = me.inventory.count("coins")
	var bread_slot := _slot_of("bread")
	driver().sim.queue_item_action(PLAYER, "drop", {"slot": _slot_of("coins")})
	driver().sim.queue_item_action(PLAYER, "drop", {"slot": bread_slot})
	await seconds(1.0)
	await press("context_menu")
	await seconds(0.1)
	await shot("loot_menu")
	await _choose(ui, "Take Denarii x%d" % coins_before)
	await seconds(1.5)
	expect(me.inventory.count("coins") == coins_before, "took the coins back")
	expect(me.inventory.count("bread") == 3, "left the dropped bread on the ground")


func _menu_labels(ui: Node) -> Array:
	var labels := []
	for i in ui._menu.item_count:
		labels.append(ui._menu.get_item_text(i))
	return labels


## Moves the menu highlight to an option with the D-pad and presses A.
func _choose(ui: Node, label: String) -> void:
	var index := _menu_labels(ui).find(label)
	expect(index != -1, "menu has '%s' (%s)" % [label, _menu_labels(ui)])
	for i in index:
		await press("ui_down")
	await press("ui_accept")
	await seconds(0.2)


func _teleport(position: Vector3) -> void:
	player().destination = null
	player().global_position = position
	await seconds(0.3)


func _entity(monster_id: String) -> Node:
	for entity in get_tree().get_nodes_in_group("sim_entities"):
		if entity.monster_id == monster_id and entity.combatant.is_alive():
			return entity
	return null


func _slot_of(item_id: String) -> int:
	var slots: Array = driver().sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1
