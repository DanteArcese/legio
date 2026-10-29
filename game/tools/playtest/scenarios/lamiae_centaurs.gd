extends "res://tools/playtest/scenario.gd"
## Vipasca's new lairs: a level-50 fighter wearing a leather bulla kills a
## lamia at the ruined shrine without being charmed, then walks onto the
## grassland, where a centaur shoots from range.

const PLAYER := 1
const Skills := preload("res://scripts/sim/skills.gd")


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for skill in ["attack", "strength", "defence", "vitality", "slayer"]:
		me.skills.xp[skill] = Skills.xp_for_level(55)
	me.max_hp = 55
	me.hp = 55
	for item in ["leather_bulla", "steel_gladius", "steel_scutum"]:
		driver().sim.give_item(PLAYER, item, 1, "test", [])
		await seconds(0.1)
		driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of(item)})
		await seconds(0.7)
	driver().sim.give_item(PLAYER, "cooked_meat", 10, "test", [])

	player().destination = null
	player().global_position = _ground(Vector3(31, 0, 425))
	await seconds(1.5)
	var lamiae := get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.monster_id == "lamia")
	expect(lamiae.size() == 4, "four lamiae at the shrine (%d)" % lamiae.size())
	await shot("shrine")
	var lamia: Node = lamiae[0]
	player().attack(lamia.entity_id)
	var charmed := false
	for i in ceili(60.0 * Engine.physics_ticks_per_second):
		charmed = charmed or driver().sim.tick < me.charmed_until
		if me.hp < 25 and _slot_of("cooked_meat") != -1:
			driver().sim.queue_item_action(PLAYER, "eat", {"slot": _slot_of("cooked_meat")})
		if not lamia.combatant.is_alive() or not me.is_alive():
			break
		await get_tree().physics_frame
	expect(not lamia.combatant.is_alive(), "the lamia is dead (her hp %d, my hp %d)" % [lamia.combatant.hp, me.hp])
	expect(me.is_alive(), "and the fighter isn't")
	expect(not charmed, "the bulla kept the charm off")
	await shot("lamia_down")

	driver().sim.queue_stop(PLAYER)
	player().destination = null
	player().global_position = _ground(Vector3(40, 0, 368))
	await seconds(0.5)
	var centaurs := get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.monster_id == "centaur")
	expect(centaurs.size() == 4, "four centaurs on the grassland (%d)" % centaurs.size())
	var ids := centaurs.map(func(c): return c.entity_id)
	var shots := []
	var listen := func(event: Dictionary) -> void:
		if event["type"] == "hit" and ids.has(event["attacker"]) and event["target"] == PLAYER:
			shots.append([event["ranged"], driver().sim.flat_distance(driver().sim.get_combatant(event["attacker"]).position, me.position)])
	driver().sim_event.connect(listen)
	# Start the fight, so it doesn't wait on a centaur wandering this way.
	var nearest: Node = centaurs[0]
	for c in centaurs:
		if c.body().global_position.distance_to(player().global_position) < nearest.body().global_position.distance_to(player().global_position):
			nearest = c
	player().attack(nearest.entity_id)
	for i in 120:
		if not shots.is_empty():
			break
		await seconds(0.5)
	driver().sim_event.disconnect(listen)
	var shot_from: float = shots[0][1] if not shots.is_empty() else -1.0
	expect(not shots.is_empty() and shots[0][0], "a centaur's blow is an arrow")
	await shot("centaurs")
	metric("shot_from_m", snappedf(shot_from, 0.1))
	expect(shot_from > 2.0, "a centaur shot from beyond melee reach (%.1f m)" % shot_from)


## A spot a metre above Vipasca's ground, so a teleport doesn't land inside a hill.
func _ground(at: Vector3) -> Vector3:
	return Vector3(at.x, main.get_node("Vipasca").height_at(at.x, at.z) + 1.0, at.z)


func _slot_of(item_id: String) -> int:
	var slots: Array = driver().sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1
