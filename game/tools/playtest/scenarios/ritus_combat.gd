extends "res://tools/playtest/scenario.gd"
## A Ritus 15 character in ritual robes buys a lituus and binding tablets,
## curses wolves in the woods, and finishes with withering tablets.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for skill in ["ritus", "defence", "vitality"]:
		me.skills.xp[skill] = me.skills.xp_for_level(15)
	me.max_hp = 15
	me.hp = 15
	driver().sim.give_item(PLAYER, "coins", 400, "test", [])
	driver().sim.give_item(PLAYER, "withering_tablet", 10, "test", [])
	var undertaker: Node3D = main.get_node("Libitinarius")
	player().buy(undertaker, "binding_tablet")
	await _wait_until(func(): return me.inventory.count("binding_tablet") > 0, 30.0)
	for item in ["lituus", "ritual_robe", "ritual_hood", "binding_tablet"]:
		player().buy(undertaker, item)
		await _wait_until(func(): return me.inventory.count(item) > 0, 30.0)
		driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of(item)})
		await seconds(0.8)
	expect(me.combat_kind() == "ritus", "casting with a lituus")
	expect(me.equipment.worn["ammo"] == "binding_tablet" and me.equipment.ammo_count == 20, "20 binding tablets ready")

	var kills := await _hunt("wolf", 2)
	await shot("wolves_cursed")
	# Switch to withering for the rest.
	driver().sim.queue_item_action(PLAYER, "unequip", {"equip_slot": "ammo"})
	await seconds(0.8)
	driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of("withering_tablet")})
	await seconds(0.8)
	kills += await _hunt("wolf", 1)
	metric("wolf_kills", kills)
	metric("curses_cast", count_events("hit", {"attacker": PLAYER, "kind": "ritus"}))
	metric("bindings", count_events("curse", {"source": PLAYER, "curse": "binding"}))
	metric("withering_pulses", count_events("hit", {"attacker": PLAYER, "kind": "withering"}))
	metric("ritus_level", me.skills.level("ritus"))
	metric("deaths", count_events("death", {"id": PLAYER}))
	expect(kills >= 3, "killed 3 wolves with curses")
	expect(count_events("curse", {"source": PLAYER, "curse": "binding"}) > 0, "bound something")
	expect(count_events("hit", {"attacker": PLAYER, "kind": "withering"}) > 0, "withered something")


func _hunt(monster_id: String, wanted: int) -> int:
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var kills := 0
	var start: int = driver().sim.tick
	while kills < wanted and driver().sim.tick - start < 2000:
		if not me.is_alive():
			await seconds(3.0)
			continue
		var target := _nearest(monster_id)
		if target == null:
			await seconds(1.0)
			continue
		var where: Vector3 = target.body().global_position
		if player().global_position.distance_to(where) > 6.0:
			await route_to(where, 5.0, 60.0)
		var before := count_events("death", {"id": target.entity_id})
		player().attack(target.entity_id)
		await seconds(0.7)
		while count_events("death", {"id": target.entity_id}) == before and me.target_id != -1 and me.is_alive():
			await seconds(0.3)
		if count_events("death", {"id": target.entity_id}) > before:
			kills += 1
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
