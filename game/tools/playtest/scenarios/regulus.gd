extends "res://tools/playtest/scenario.gd"
## Regulus, the basilisk king: fight him in the deep gallery's chamber with
## a mirror shield, step out of the green mark whenever he spits venom, and
## see him enrage and fall, leaving his loot.

const PLAYER := 1


func run() -> void:
	await seconds(0.5)
	var sim: RefCounted = driver().sim
	var me: RefCounted = sim.get_combatant(PLAYER)
	for skill in ["attack", "strength", "defence", "vitality"]:
		me.skills.xp[skill] = me.skills.xp_for_level(85)
	me.max_hp = 85
	me.hp = 85
	me.skills.xp["slayer"] = me.skills.xp_for_level(60)
	for item_id in ["steel_gladius", "steel_lorica", "steel_galea", "mirror_shield"]:
		sim.give_item(PLAYER, item_id, 1, "test", [])
	for item_id in ["steel_gladius", "steel_lorica", "steel_galea", "mirror_shield"]:
		for slot in me.inventory.size:
			if me.inventory.slots[slot] and me.inventory.slots[slot]["item"] == item_id:
				sim.queue_item_action(PLAYER, "equip", {"slot": slot})
				break
		await seconds(0.7)
	expect(me.equipment.worn["shield"] == "mirror_shield", "holding the mirror shield")
	for i in 10:
		sim.give_item(PLAYER, "cooked_tuna", 1, "test", [])

	# Straight into the chamber, below the king.
	var start := Vector3(182, 0, 419)
	player().global_position = start + Vector3(0, 1, 0)
	sim.set_position(PLAYER, start)
	await seconds(1.0)
	var boss_entity: Node = get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.monster_id == "regulus")[0]
	var regulus: RefCounted = boss_entity.combatant
	await walk_to(Vector3(182, 0, 424), 0.8, 20.0)
	await shot("clearing")
	player().attack(boss_entity.entity_id)

	var dodged := 0
	var hit_by_venom := 0
	var seen := events.size()
	for i in ceili(180.0 / 0.1):
		if not regulus.is_alive():
			break
		for event in events.slice(seen):
			if event["type"] == "strike_land" and event.get("strike", 0) > 0:
				var venom_hits := events.slice(seen).filter(func(e): return e["type"] == "hit" and e.get("kind") == "venom" and e["target"] == PLAYER)
				if venom_hits.is_empty():
					dodged += 1
		hit_by_venom += events.slice(seen).filter(func(e): return e["type"] == "hit" and e.get("kind") == "venom" and e["target"] == PLAYER).size()
		var warns := events.slice(seen).filter(func(e): return e["type"] == "strike_warn")
		seen = events.size()
		if not warns.is_empty():
			# Click the ground out of the mark (which drops combat, so the
			# character doesn't walk straight back in), then close in again.
			var mark: Vector3 = warns[-1]["position"]
			var away: Vector3 = (mark - regulus.position).cross(Vector3.UP).normalized() * 2.6
			if dodged == 0:
				await seconds(0.3)
				await shot("venom_mark")
			player().walk_here(mark + away)
			# Wait for it to land before closing in again.
			while sim.tick < warns[-1]["lands_at"]:
				await get_tree().physics_frame
			player().attack(boss_entity.entity_id)
		if me.hp < 35 and me.inventory.count("cooked_tuna") > 0:
			sim.queue_item_action(PLAYER, "eat", {"slot": me.inventory.slots.find(me.inventory.slots.filter(func(s): return s != null and s["item"] == "cooked_tuna")[0])})
		await seconds(0.1)

	metric("venom_dodged", dodged)
	metric("venom_hits", hit_by_venom)
	metric("hp_left", me.hp)
	expect(count_events("strike_warn") >= 1, "Regulus spat venom at least once")
	expect(dodged >= 2 and hit_by_venom <= 1, "stepping out of the mark dodges the venom (%d dodged, %d hit)" % [dodged, hit_by_venom])
	expect(count_events("enrage", {"id": regulus.id}) == 1, "he enraged when low")
	expect(not regulus.is_alive(), "Regulus falls")
	expect(me.remedy_boost("attack") == 0, "the mirror shield kept the gaze off")
	await seconds(1.0)
	var near: Array = sim.ground_piles().filter(func(pile): return pile["position"].distance_to(regulus.position) < 3.0)
	expect(near.size() >= 1 and near[0]["items"].any(func(e): return e["item"] == "coins"), "and leaves his loot")
	await shot("victory")
