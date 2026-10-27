extends "res://tools/playtest/scenario.gd"
## Cyclopes in the hollow on Seriphos: walk up from the temple path, fight
## one, step out of the amber mark when it heaves a boulder, and see it fall.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var sim: RefCounted = driver().sim
	var me: RefCounted = sim.get_combatant(PLAYER)
	for skill in ["attack", "strength", "defence", "vitality"]:
		me.skills.xp[skill] = me.skills.xp_for_level(75)
	me.max_hp = 75
	me.hp = 75
	for item_id in ["steel_gladius", "steel_lorica", "steel_galea", "steel_scutum"]:
		sim.give_item(PLAYER, item_id, 1, "test", [])
		for slot in me.inventory.size:
			if me.inventory.slots[slot] and me.inventory.slots[slot]["item"] == item_id:
				sim.queue_item_action(PLAYER, "equip", {"slot": slot})
				break
		await seconds(0.7)
	player().destination = null
	player().global_position = Vector3(-272, 1, 308)
	await seconds(1.0)
	expect(await walk_to(Vector3(-263, 0, 336), 1.0, 40.0), "up the path to the hollow")
	await shot("hollow")
	var cyclopes := get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.monster_id == "cyclops")
	expect(cyclopes.size() == 4, "four cyclopes (%d)" % cyclopes.size())
	var target: Node = cyclopes[0]
	player().attack(target.entity_id)
	var seen := events.size()
	for i in ceili(150.0 / 0.1):
		if not target.combatant.is_alive():
			break
		var warns := events.slice(seen).filter(func(e): return e["type"] == "strike_warn")
		seen = events.size()
		if not warns.is_empty():
			var mark: Vector3 = warns[-1]["position"]
			var away: Vector3 = (mark - target.combatant.position).cross(Vector3.UP).normalized() * 2.4
			if count_events("strike_warn") == 1:
				await seconds(0.3)
				await shot("boulder_mark")
			player().walk_here(mark + away)
			while sim.tick < warns[-1]["lands_at"]:
				await get_tree().physics_frame
			player().attack(target.entity_id)
		me.hp = maxi(me.hp, 40)
		await seconds(0.1)
	expect(count_events("strike_warn") >= 1, "it heaved at least one boulder")
	expect(not target.combatant.is_alive(), "the cyclops falls")
	metric("boulder_hits", events.filter(func(e): return e["type"] == "hit" and e.get("kind") == "boulder" and e["target"] == PLAYER).size())
