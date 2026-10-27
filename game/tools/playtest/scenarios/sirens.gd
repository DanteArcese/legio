extends "res://tools/playtest/scenario.gd"
## The sirens' rocks at Portus Salis: buy beeswax from the sacerdos, sew
## earplugs, and kill a siren on the west beach.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for skill in ["attack", "strength", "defence", "vitality", "slayer", "crafting"]:
		me.skills.xp[skill] = me.skills.xp_for_level(45)
	me.hp = me.max_hp
	driver().sim.give_item(PLAYER, "coins", 100, "test", [])
	for entry in [["needle", 1], ["linen", 1], ["iron_gladius", 1]]:
		driver().sim.give_item(PLAYER, entry[0], entry[1], "test", [])
	var sacerdos: Node3D = _sacerdos()
	expect(sacerdos != null, "found the sacerdos")
	if sacerdos:
		var buy: Array = WorldMenu.wares_for(player(), sacerdos).filter(func(o): return o[0].begins_with("Buy beeswax"))
		expect(buy.size() == 1, "the sacerdos sells beeswax")
		if buy.size() == 1:
			buy[0][1].call()
		await _wait_until(func(): return me.inventory.count("beeswax") > 0, 40.0)
	expect(me.inventory.count("beeswax") >= 2, "bought beeswax (%d)" % me.inventory.count("beeswax"))
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "leatherwork", "recipe": "wax_earplugs", "count": 1})
	await _wait_until(func(): return me.inventory.count("wax_earplugs") == 1, 10.0)
	for item_id in ["wax_earplugs", "iron_gladius"]:
		driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of(item_id)})
		await seconds(0.7)
	expect(me.equipment.worn["head"] == "wax_earplugs", "wearing earplugs")

	player().destination = null
	player().global_position = Vector3(-330, 1, 4)
	await seconds(1.0)
	var sirens := get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.monster_id == "siren")
	expect(sirens.size() == 4, "four sirens on the rocks (%d)" % sirens.size())
	await walk_to(Vector3(-337, 0, 6), 0.8, 30.0)
	main.get_node("CameraRig")._orbit(PI * 0.6, 0.0)
	await seconds(0.5)
	await shot("siren_rocks")
	main.get_node("CameraRig")._orbit(-PI * 0.6, 0.0)
	var target: Node = sirens[1]
	var kills_before := count_events("death", {"id": target.entity_id})
	for i in 120:
		if not target.combatant.is_alive():
			break
		if me.target_id == -1:
			driver().sim.queue_attack(PLAYER, target.entity_id)
		me.hp = me.max_hp
		await seconds(0.5)
	expect(count_events("death", {"id": target.entity_id}) > kills_before, "killed a siren with earplugs in")
	metric("entranced", events.filter(func(e): return e["type"] == "message" and "song holds you" in e.get("text", "")).size())
	expect(not events.any(func(e): return e["type"] == "message" and "song holds you" in e.get("text", "")), "never held by the song")


func _sacerdos() -> Node3D:
	return _find(main, func(n): return n is Node3D and n.get_meta("shop_id", "") == "sacerdos")


func _find(node: Node, test: Callable) -> Node:
	if test.call(node):
		return node
	for child in node.get_children():
		var found := _find(child, test)
		if found:
			return found
	return null


func _slot_of(item_id: String) -> int:
	var slots: Array = me_slots()
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1


func me_slots() -> Array:
	return driver().sim.get_combatant(PLAYER).inventory.slots


func _wait_until(condition: Callable, timeout: float) -> void:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await seconds(0.25)
		waited += 0.25
