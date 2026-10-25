extends "res://tools/playtest/scenario.gd"
## A fresh character buys a hunting bow and arrows from Aulus, shoots rats
## from range, and picks the arrows back up. Reports Ranged XP, arrows used
## and recovered, and damage taken.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	driver().sim.give_item(PLAYER, "coins", 200, "test", [])
	var aulus: Node3D = main.get_node("VenatorAulus")
	player().buy(aulus, "hunting_bow")
	await _wait_until(func(): return me.inventory.count("hunting_bow") == 1, 20.0)
	driver().sim.queue_item_action(PLAYER, "buy", {"venator": "aulus", "item": "bronze_arrow"})
	await seconds(1.0)
	expect(me.inventory.count("bronze_arrow") == 50, "bought 50 arrows")
	driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of("hunting_bow")})
	driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of("bronze_arrow")})
	await seconds(1.0)
	expect(me.is_ranged() and me.equipment.ammo_count == 50, "bow and arrows equipped")

	await route_to(Vector3(13, 0, 4), 1.0)
	var start: int = driver().sim.tick
	var kills := 0
	while kills < 10 and driver().sim.tick - start < 1500 and me.equipment.ammo_count > 0:
		var rat := _nearest("rat")
		if rat == null:
			await seconds(1.0)
			continue
		var before := count_events("death", {"id": rat.entity_id})
		player().attack(rat.entity_id)
		await seconds(0.7)
		while count_events("death", {"id": rat.entity_id}) == before and me.target_id != -1:
			await seconds(0.3)
		if count_events("death", {"id": rat.entity_id}) > before:
			kills += 1
	await shot("after_shooting")
	var used: int = 50 - me.equipment.ammo_count
	# Pick up every pile with arrows in it.
	for pile in get_tree().get_nodes_in_group("loot_piles"):
		if pile.items.any(func(e): return e["item"] == "bronze_arrow"):
			player().take(pile, "bronze_arrow")
			await _wait_until(func(): return player().destination == null, 10.0)
			await seconds(1.0)
	metric("rat_kills", kills)
	metric("arrows_used", used)
	metric("arrows_recovered", me.inventory.count("bronze_arrow"))
	metric("ranged_level", me.skills.level("ranged"))
	metric("damage_taken", _damage_taken())
	expect(kills >= 10, "shot 10 rats")
	expect(me.skills.xp["ranged"] > 0.0, "gained Ranged XP")
	expect(me.inventory.count("bronze_arrow") > used / 2, "recovered most arrows")


func _damage_taken() -> int:
	var total := 0
	for event in events:
		if event["type"] == "hit" and event["target"] == PLAYER:
			total += event["damage"]
	return total


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
