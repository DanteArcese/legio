extends "res://tools/playtest/scenario.gd"
## Crafting: tan boar hides at the smithy's tanning rack, then sew a leather
## jerkin from the inventory's Sew option and wear it. The wolfskin set
## gets a look too.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.skills.xp["crafting"] = me.skills.xp_for_level(25)
	me.skills.xp["ranged"] = me.skills.xp_for_level(20)
	for item in [["boar_hide", 3], ["needle", 1], ["thread", 10], ["wolf_pelt", 3]]:
		driver().sim.give_item(PLAYER, item[0], item[1], "test", [])
	var rack: Node3D = main.get_node("Smithy/TanningRack")
	await route_to(rack.global_position + Vector3(0, 0, 1.4), 0.4, 60.0)
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "tan", "recipe": "leather", "count": 3})
	await _wait_until(func(): return me.inventory.count("leather") == 3, 20.0)
	expect(me.inventory.count("leather") == 3, "tanned three hides")

	var game_ui: Node = main.get_node("GameUi")
	var options: Array = game_ui._inventory_options(_slot_of("leather")).map(func(o): return o[0])
	expect(options.has("Sew"), "leather has a Sew option (%s)" % [options])
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "leatherwork", "recipe": "leather_jerkin", "count": 1})
	await _wait_until(func(): return me.inventory.count("leather_jerkin") == 1, 10.0)
	expect(me.inventory.count("leather_jerkin") == 1, "sewn a leather jerkin")
	driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of("leather_jerkin")})
	await seconds(1.0)
	expect(me.equipment.worn["body"] == "leather_jerkin", "wearing it")
	await shot("leather_jerkin")

	for item_id in ["wolfskin_jerkin", "wolfskin_hood"]:
		driver().sim.give_item(PLAYER, item_id, 1, "test", [])
		driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of(item_id)})
		await seconds(0.7)
	expect(me.equipment.worn["head"] == "wolfskin_hood", "wearing the wolfskin hood")
	await seconds(0.5)
	await shot("wolfskin")


func _slot_of(item_id: String) -> int:
	var slots: Array = driver().sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
