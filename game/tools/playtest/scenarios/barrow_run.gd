extends "res://tools/playtest/scenario.gd"
## A Slayer-10 character buys a whitethorn charm from Aulus, walks to the
## barrow, goes in, fights through to the strix, and climbs back out.

const PLAYER := 1


func run() -> void:
	await seconds(0.3) # let the navigation map sync
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for skill in ["attack", "strength", "defence", "vitality"]:
		me.skills.xp[skill] = me.skills.xp_for_level(35)
	me.skills.xp["slayer"] = me.skills.xp_for_level(10)
	me.max_hp = 35
	me.hp = 35
	driver().sim.give_item(PLAYER, "coins", 200, "test", [])
	# Lemurs often come in twos and threes; bring plenty.
	driver().sim.give_item(PLAYER, "bread", 15, "test", [])

	# Buy and wear the charm via Aulus's menu option.
	var aulus: Node3D = main.get_node("VenatorAulus")
	player().buy(aulus, "whitethorn_charm")
	await _wait_until(func(): return me.inventory.count("whitethorn_charm") == 1, 20.0)
	expect(me.inventory.count("whitethorn_charm") == 1, "bought a whitethorn charm")
	driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of("whitethorn_charm")})
	await seconds(1.0)
	expect(me.equipment.worn["neck"] == "whitethorn_charm", "wearing the charm")

	# Walk to the barrow and go in.
	var entrance: Node3D = main.get_node("BarrowEntrance")
	expect(await route_to(entrance.global_position + Vector3(0, 0, 1.6), 0.6, 90.0), "reached the barrow entrance")
	player().travel(entrance)
	await seconds(1.0)
	expect(main.get_node("AreaLighting").underground, "now underground")
	await shot("barrow_entry")

	# Fight lemurs, then the strix, eating when low.
	var lemur_kills := await _fight("lemur", 2, 120.0)
	await shot("upper_halls")
	var strix_kills := await _fight("strix", 1, 120.0)
	await shot("depths")
	metric("lemur_kills", lemur_kills)
	metric("strix_kills", strix_kills)
	metric("deaths", count_events("death", {"id": PLAYER}))
	metric("slayer_xp", int(me.skills.xp["slayer"]))
	expect(strix_kills >= 1, "killed a strix while warded")

	# Back to the stairs and out.
	if main.get_node("AreaLighting").underground:
		var stairs: Node3D = main.get_node("BarrowExit")
		player().travel(stairs)
		await _wait_until(func(): return not main.get_node("AreaLighting").underground, 60.0)
	expect(not main.get_node("AreaLighting").underground, "climbed back out")


func _fight(monster_id: String, kills_wanted: int, timeout: float) -> int:
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var kills := 0
	var frames_left := ceili(timeout * Engine.physics_ticks_per_second)
	while kills < kills_wanted and frames_left > 0 and me.is_alive():
		if me.hp < 20 and _slot_of("bread") != -1:
			driver().sim.queue_item_action(PLAYER, "eat", {"slot": _slot_of("bread")})
		if me.target_id == -1:
			var target := _nearest(monster_id)
			if target:
				var before := count_events("death", {"id": target.entity_id})
				player().attack(target.entity_id)
				while count_events("death", {"id": target.entity_id}) == before and frames_left > 0 and me.is_alive():
					if me.hp < 20 and _slot_of("bread") != -1:
						driver().sim.queue_item_action(PLAYER, "eat", {"slot": _slot_of("bread")})
					await seconds(0.5)
					frames_left -= 30
				if count_events("death", {"id": target.entity_id}) > before:
					kills += 1
		await seconds(0.5)
		frames_left -= 30
	return kills


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
