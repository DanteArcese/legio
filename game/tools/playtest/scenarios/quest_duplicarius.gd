extends "res://tools/playtest/scenario.gd"
## Duplicarius: the optio's missing silver. Ask the Gaulish merchant, find
## the latro on the south-west road, and bring the pay chest back.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var quest_ui: Node = main.get_node("QuestUi")
	var optio: Node3D = main.get_node("OptioGaius")
	var merchant: Node3D = main.get_node("Forum/Merchant")
	for quest_id in ["tiro", "miles"]:
		me.quests[quest_id] = {"step": 9, "progress": 0, "done": true}
	for skill in ["attack", "strength", "defence", "vitality"]:
		me.skills.xp[skill] = me.skills.xp_for_level(35)
	me.skills.xp["thieving"] = me.skills.xp_for_level(5)
	me.max_hp = 35
	me.hp = 35
	driver().sim.give_item(PLAYER, "iron_gladius", 1, "test", [])
	driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of("iron_gladius")})

	await _talk_through(optio)
	expect(me.quests.get("duplicarius", {}).get("step", -1) == 0, "Duplicarius started")
	var options: Array = WorldMenu.options_for(player(), merchant).map(func(o): return o[0])
	expect(options.has("Talk to Merchant") and options.has("Pickpocket Merchant"), "the merchant can be talked to or robbed (%s)" % [options])
	await _talk_through(merchant)
	expect(me.quests["duplicarius"]["step"] == 1, "the merchant names the latro")
	await shot("merchant")

	var latro := _nearest("latro")
	await route_to(latro.body().global_position, 3.0, 150.0)
	latro = _nearest("latro")
	player().attack(latro.entity_id)
	await _wait_until(func(): return me.inventory.count("stolen_pay_chest") == 1 or not me.is_alive(), 60.0)
	expect(me.inventory.count("stolen_pay_chest") == 1, "recovered the pay chest")

	await route_to(optio.global_position + Vector3(0, 0, -1.5), 1.0, 150.0)
	await _talk_through(optio)
	expect(me.quests["duplicarius"]["done"], "Duplicarius complete")
	expect(me.inventory.count("spatha") == 1, "rewarded a spatha")
	await shot("duplicarius_complete")


const WorldMenu := preload("res://scripts/player/world_menu.gd")


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
