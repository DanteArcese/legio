extends "res://tools/playtest/scenario.gd"
## A Ritus 55 caster inscribes Silencing and Manes tablets at the tomb, then
## calls a shade on the wolves and silences one.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for skill in ["ritus", "defence", "vitality"]:
		me.skills.xp[skill] = me.skills.xp_for_level(55)
	me.max_hp = 55
	me.hp = 55
	for item in [["stylus", 1], ["lead_sheet", 4], ["iron_nails", 15], ["strix_feather", 4], ["lemur_ash", 2], ["lituus", 1]]:
		driver().sim.give_item(PLAYER, item[0], item[1], "test", [])
	var tomb: Node3D = main.get_node("Smithy/Tomb")
	await route_to(tomb.global_position + Vector3(1.6, 0, 0), 0.4, 60.0)
	for recipe in [["silencing_tablet", 10], ["manes_tablet", 6]]:
		driver().sim.queue_item_action(PLAYER, "craft", {"kind": "inscribe", "recipe": recipe[0], "count": 2})
		await _wait_until(func(): return me.inventory.count(recipe[0]) >= recipe[1], 30.0)
	expect(me.inventory.count("silencing_tablet") == 10, "inscribed 10 silencing tablets")
	expect(me.inventory.count("manes_tablet") == 6, "inscribed 6 manes tablets")

	driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of("lituus")})
	driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of("manes_tablet")})
	await seconds(0.8)
	var wolf := _nearest("wolf")
	await route_to(wolf.body().global_position, 5.0, 90.0)
	player().attack(wolf.entity_id)
	await _wait_until(func(): return count_events("summon", {"owner": PLAYER}) > 0, 20.0)
	expect(count_events("summon", {"owner": PLAYER}) > 0, "a shade rose")
	await seconds(1.5)
	await shot("shade")
	await _wait_until(func(): return count_events("death", {"id": wolf.entity_id}) > 0, 40.0)
	expect(count_events("death", {"id": wolf.entity_id}) > 0, "the wolf fell")
	metric("shade_hits", events.filter(func(e): return e["type"] == "hit" and e["attacker"] == 100000 + PLAYER).size())

	driver().sim.queue_item_action(PLAYER, "unequip", {"equip_slot": "ammo"})
	await seconds(0.7)
	driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of("silencing_tablet")})
	await seconds(0.7)
	# A curse only lands on a target that survives the hit, and at Ritus 55
	# one hit can kill a wolf outright, so this one gets extra hitpoints.
	for attempt in 3:
		if count_events("curse", {"source": PLAYER, "curse": "silencing"}) > 0:
			break
		var other := _nearest("wolf")
		if other == null:
			await seconds(3.0)
			continue
		other.combatant.max_hp = 200
		other.combatant.hp = 200
		player().attack(other.entity_id)
		await _wait_until(func(): return count_events("curse", {"source": PLAYER, "curse": "silencing"}) > 0 \
			or not other.combatant.is_alive(), 30.0)
	expect(count_events("curse", {"source": PLAYER, "curse": "silencing"}) > 0, "silenced a wolf")


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
