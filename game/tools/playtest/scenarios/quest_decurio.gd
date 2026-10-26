extends "res://tools/playtest/scenario.gd"
## Decurio: the sacerdos's black beans, the Larva in the barrow's depths,
## and citizenship.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var optio: Node3D = main.get_node("OptioGaius")
	var sacerdos: Node3D = main.get_node("Sacerdos")
	for quest_id in ["tiro", "miles", "duplicarius"]:
		me.quests[quest_id] = {"step": 9, "progress": 0, "done": true}
	for skill in ["attack", "strength", "defence", "vitality"]:
		me.skills.xp[skill] = me.skills.xp_for_level(60)
	me.skills.xp["slayer"] = me.skills.xp_for_level(20)
	me.max_hp = 60
	me.hp = 60
	for item in [["spatha", 1], ["whitethorn_charm", 1], ["cooked_mackerel", 12]]:
		driver().sim.give_item(PLAYER, item[0], item[1], "test", [])
	for item_id in ["spatha", "whitethorn_charm"]:
		driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of(item_id)})
		await seconds(0.7)

	await _talk_through(optio)
	expect(me.quests.get("decurio", {}).get("step", -1) == 0, "Decurio started")
	await _talk_through(sacerdos)
	expect(me.inventory.count("black_beans") == 9, "the sacerdos gave nine black beans")

	var entrance: Node3D = main.get_node("BarrowEntrance")
	expect(await route_to(entrance.global_position + Vector3(0, 0, 1.6), 0.6, 120.0), "reached the barrow")
	player().travel(entrance)
	await seconds(1.0)
	var larva := _nearest("larva")
	expect(larva != null, "the Larva waits in the depths")
	if larva:
		player().attack(larva.entity_id)
		await _wait_until(func():
			if me.hp < 30 and _slot_of("cooked_mackerel") != -1:
				driver().sim.queue_item_action(PLAYER, "eat", {"slot": _slot_of("cooked_mackerel")})
			if me.target_id == -1 and larva.combatant.is_alive():
				player().attack(larva.entity_id)
			return me.quests["decurio"]["step"] >= 2 or not me.is_alive(), 240.0)
		await shot("larva")
	expect(me.quests["decurio"]["step"] == 2, "laid the Larva to rest")
	metric("deaths", count_events("death", {"id": PLAYER}))

	player().travel(main.get_node("BarrowExit"))
	await _wait_until(func(): return not main.get_node("AreaLighting").underground, 90.0)
	await route_to(optio.global_position + Vector3(0, 0, -1.5), 1.0, 180.0)
	await _talk_through(optio)
	expect(me.quests["decurio"]["done"], "Decurio complete")
	expect(me.inventory.count("diploma") == 1, "the bronze diploma")
	await shot("civis_romanus")


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
