extends "res://tools/playtest/scenario.gd"
## Miles: a seasoned tiro takes the second rank. Wolves in the woods, logs
## and nails for the palisade, a look at the barrow, and back to the optio.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var quest_ui: Node = main.get_node("QuestUi")
	var optio: Node3D = main.get_node("OptioGaius")
	me.quests["tiro"] = {"step": 5, "progress": 0, "done": true}
	for skill in ["attack", "strength", "defence", "vitality"]:
		me.skills.xp[skill] = me.skills.xp_for_level(40)
	me.max_hp = 40
	me.hp = 40
	driver().sim.give_item(PLAYER, "iron_gladius", 1, "test", [])
	driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of("iron_gladius")})

	await _talk_through(optio)
	expect(me.quests.get("miles", {}).get("step", -1) == 0, "Miles started")

	await route_to(Vector3(0, 0, -34), 2.0, 120.0)
	for attempt in 20:
		if me.quests["miles"]["step"] >= 1:
			break
		var wolf := _nearest_wolf()
		if wolf == null:
			await seconds(3.0)
			continue
		player().attack(wolf.entity_id)
		await _wait_until(func(): return not wolf.combatant.is_alive() or not me.is_alive(), 40.0)
		me.hp = me.max_hp
		await seconds(0.7)
	expect(me.quests["miles"]["step"] == 1, "five wolves killed")

	driver().sim.give_item(PLAYER, "logs", 10, "test", [])
	driver().sim.give_item(PLAYER, "bronze_nails", 15, "test", [])
	await press("quest_log")
	expect("logs 10/10" in quest_ui.log_text(), "the log counts what you carry")
	await shot("quest_log_deliver")
	await press("quest_log")
	await _talk_through(optio)
	expect(me.quests["miles"]["step"] == 2, "logs and nails delivered")

	await route_to(Vector3(-44, 0, -33), 2.0, 150.0)
	await seconds(0.7)
	expect(me.quests["miles"]["step"] == 3, "scouted the barrow")
	await shot("barrow_scouted")

	await route_to(optio.global_position + Vector3(0, 0, -1.5), 1.0, 150.0)
	await _talk_through(optio)
	expect(me.quests["miles"]["done"], "Miles complete")
	expect(me.inventory.count("lorica_hamata") == 1, "rewarded mail")
	await shot("miles_complete")


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


func _nearest_wolf() -> Node:
	var best: Node = null
	var best_distance := INF
	for entity in get_tree().get_nodes_in_group("sim_entities"):
		if entity.monster_id != "wolf" or not entity.combatant.is_alive():
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
