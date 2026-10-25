extends "res://tools/playtest/scenario.gd"
## A mid-level character (15 melee) takes a contract from Aulus, hunts the
## assigned monster with the starting kit, and hands it in. Reports how long
## the contract took and what it paid.

const PLAYER := 1


func run() -> void:
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for skill in ["attack", "strength", "defence"]:
		me.skills.xp[skill] = me.skills.xp_for_level(15)
	driver().sim.queue_item_action(PLAYER, "equip", {"slot": 0})
	var aulus: Vector3 = main.get_node("VenatorAulus").global_position
	expect(await walk_to(aulus + Vector3(1.8, 0, 0), 0.4), "reached Aulus")
	await press("interact")
	await seconds(1.0)
	expect(not me.slayer_task.is_empty(), "got a contract")
	await shot("contract")
	var task: Dictionary = me.slayer_task.duplicate()
	metric("task", "%d %s" % [task.get("total", 0), task.get("monster", "?")])

	var start: int = driver().sim.tick
	var deadline := start + 6000
	while not me.slayer_task.is_empty() and driver().sim.tick < deadline:
		if me.is_alive() and me.target_id == -1:
			var target := _nearest(task["monster"])
			if target != -1:
				driver().sim.queue_attack(PLAYER, target)
		if me.is_alive() and me.hp <= me.max_hp / 3 and _slot_of("bread") != -1:
			driver().sim.queue_item_action(PLAYER, "eat", {"slot": _slot_of("bread")})
		await seconds(0.5)
	await shot("done")
	metric("minutes", snappedf((driver().sim.tick - start) * 0.6 / 60.0, 0.1))
	metric("deaths", count_events("death", {"id": PLAYER}))
	metric("slayer_level", me.skills.level("slayer"))
	metric("points", me.slayer_points)
	expect(me.slayer_task.is_empty(), "finished the contract within an hour of game time")
	expect(count_events("slayer_complete", {"id": PLAYER}) == 1, "completion event")
	expect(me.slayer_points > 0, "earned points")


func _nearest(monster_id: String) -> int:
	var best := -1
	var best_distance := INF
	for entity in get_tree().get_nodes_in_group("sim_entities"):
		if entity.monster_id != monster_id or not entity.combatant.is_alive():
			continue
		var distance := player().global_position.distance_to(entity.body().global_position)
		if distance < best_distance:
			best = entity.entity_id
			best_distance = distance
	return best


func _slot_of(item_id: String) -> int:
	var slots: Array = driver().sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1
