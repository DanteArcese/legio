extends "res://tools/playtest/scenario.gd"
## Harpies at the Harbour: Harbourmaster Lucilla's bounty on the harpies of
## the eastern rocks, feathers as proof, linen for the fishmonger's nets.

const PLAYER := 1


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for skill in ["attack", "strength", "defence", "vitality"]:
		me.skills.xp[skill] = me.skills.xp_for_level(60)
	me.skills.xp["slayer"] = me.skills.xp_for_level(20)
	me.skills.xp["fishing"] = me.skills.xp_for_level(15)
	me.max_hp = 60
	me.hp = 60
	for item in [["spatha", 1], ["cooked_tuna", 10]]:
		driver().sim.give_item(PLAYER, item[0], item[1], "test", [])
	driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of("spatha")})
	player()._arrive_through(main.get_node("RoadToPortus"))
	await seconds(0.5)
	await walk_to(Vector3(-300, 0, 0), 0.6, 60.0)
	await shot("harbour")

	var lucilla: Node3D = main.get_node("PortusSalis/Harbourmaster")
	await _talk_through(lucilla)
	expect(me.quests.get("harpies_at_the_harbour", {}).get("step", -1) == 0, "the harbourmaster's quest started")

	await walk_to(Vector3(-262, 0, -20), 1.5, 90.0)
	for attempt in 20:
		if me.quests["harpies_at_the_harbour"]["step"] >= 1:
			break
		var harpy := _nearest("harpy")
		if harpy == null:
			await seconds(3.0)
			continue
		player().attack(harpy.entity_id)
		await _wait_until(func():
			if me.hp < 35 and _slot_of("cooked_tuna") != -1:
				driver().sim.queue_item_action(PLAYER, "eat", {"slot": _slot_of("cooked_tuna")})
			return not harpy.combatant.is_alive() or not me.is_alive(), 60.0)
		await seconds(0.7)
	expect(me.quests["harpies_at_the_harbour"]["step"] == 1, "four harpies down")

	driver().sim.give_item(PLAYER, "harpy_feather", 3, "test", [])
	driver().sim.give_item(PLAYER, "linen", 2, "test", [])
	await walk_to(Vector3(-300, 0, 0), 1.0, 90.0)
	await _talk_through(lucilla)
	expect(me.quests["harpies_at_the_harbour"]["step"] == 2, "feathers handed in")
	await _talk_through(main.get_node("PortusSalis/Fishmonger"))
	expect(me.quests["harpies_at_the_harbour"]["step"] == 3, "linen for the nets")
	await _talk_through(lucilla)
	expect(me.quests["harpies_at_the_harbour"]["done"], "quest complete")
	expect(me.inventory.count("harpy_arrow") == 60, "rewarded harpy arrows")


func _talk_through(npc: Node3D) -> void:
	var quest_ui: Node = main.get_node("QuestUi")
	player().talk(npc)
	await _wait_until(func(): return quest_ui.is_dialogue_open(), 60.0)
	for i in 10:
		if not quest_ui.is_dialogue_open():
			break
		await press("interact")


func _slot_of(item_id: String) -> int:
	var slots: Array = driver().sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1


func _nearest(monster_id: String) -> Node:
	var best: Node = null
	var best_distance := INF
	for entity in get_tree().get_nodes_in_group("sim_entities"):
		if entity.monster_id != monster_id or not entity.combatant.is_alive():
			continue
		var distance := player().global_position.distance_to(entity.body().global_position)
		if distance < best_distance:
			best = entity
			best_distance = distance
	return best


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
