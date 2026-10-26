extends "res://tools/playtest/scenario.gd"
## Hrodgar the War-chief: fight him in his clearing beyond the Limes, step
## out of the red mark whenever he throws a spear, and see him enrage and
## fall, leaving his loot.

const PLAYER := 1


func run() -> void:
	await seconds(0.5)
	var sim: RefCounted = driver().sim
	var me: RefCounted = sim.get_combatant(PLAYER)
	for skill in ["attack", "strength", "defence", "vitality"]:
		me.skills.xp[skill] = me.skills.xp_for_level(85)
	me.max_hp = 85
	me.hp = 85
	for item_id in ["spatha", "lorica_hamata", "iron_galea", "iron_scutum"]:
		sim.give_item(PLAYER, item_id, 1, "test", [])
	for i in 4:
		sim.queue_item_action(PLAYER, "equip", {"slot": 0})
		await seconds(0.7)
	for i in 10:
		sim.give_item(PLAYER, "cooked_tuna", 1, "test", [])

	# Straight to the path below the clearing.
	var start := Vector3(39, 0, -428)
	player().global_position = start + Vector3(0, 1, 0)
	sim.set_position(PLAYER, start)
	await seconds(1.0)
	var boss_entity: Node = get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.monster_id == "hrodgar")[0]
	var hrodgar: RefCounted = boss_entity.combatant
	await walk_to(Vector3(37, 0, -434), 0.8, 20.0)
	await shot("clearing")
	player().attack(boss_entity.entity_id)

	var dodged := 0
	var hit_by_spear := 0
	var seen := events.size()
	for i in ceili(180.0 / 0.1):
		if not hrodgar.is_alive():
			break
		for event in events.slice(seen):
			if event["type"] == "strike_land" and event.get("strike", 0) > 0:
				var spear_hits := events.slice(seen).filter(func(e): return e["type"] == "hit" and e.get("kind") == "spear" and e["target"] == PLAYER)
				if spear_hits.is_empty():
					dodged += 1
		hit_by_spear += events.slice(seen).filter(func(e): return e["type"] == "hit" and e.get("kind") == "spear" and e["target"] == PLAYER).size()
		var warns := events.slice(seen).filter(func(e): return e["type"] == "strike_warn")
		seen = events.size()
		if not warns.is_empty():
			# Click the ground out of the mark (which drops combat, so the
			# character doesn't walk straight back in), then close in again.
			var mark: Vector3 = warns[-1]["position"]
			var away: Vector3 = (mark - hrodgar.position).cross(Vector3.UP).normalized() * 2.6
			if dodged == 0:
				await seconds(0.3)
				await shot("spear_mark")
			player().walk_here(mark + away)
			# Wait for it to land before closing in again.
			while sim.tick < warns[-1]["lands_at"]:
				await get_tree().physics_frame
			player().attack(boss_entity.entity_id)
		if me.hp < 35 and me.inventory.count("cooked_tuna") > 0:
			sim.queue_item_action(PLAYER, "eat", {"slot": me.inventory.slots.find(me.inventory.slots.filter(func(s): return s != null and s["item"] == "cooked_tuna")[0])})
		await seconds(0.1)

	metric("spears_dodged", dodged)
	metric("spear_hits", hit_by_spear)
	metric("hp_left", me.hp)
	expect(count_events("strike_warn") >= 1, "Hrodgar threw at least one spear")
	expect(dodged >= 2 and hit_by_spear <= 1, "stepping out of the mark dodges the spear (%d dodged, %d hit)" % [dodged, hit_by_spear])
	expect(count_events("enrage", {"id": hrodgar.id}) == 1, "he enraged when low")
	expect(not hrodgar.is_alive(), "Hrodgar falls")
	await seconds(1.0)
	var near: Array = sim.ground_piles().filter(func(pile): return pile["position"].distance_to(hrodgar.position) < 3.0)
	expect(near.size() >= 1 and near[0]["items"].any(func(e): return e["item"] == "coins"), "and leaves his loot")
	await shot("victory")
