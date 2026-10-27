extends "res://tools/playtest/scenario.gd"
## The gorgons' ruins on Seriphos: stone figures among broken walls, and a
## hunter with a mirror shield kills a gorgon without being turned to stone.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var sim: RefCounted = driver().sim
	var me: RefCounted = sim.get_combatant(PLAYER)
	for skill in ["attack", "strength", "defence", "vitality", "slayer"]:
		me.skills.xp[skill] = me.skills.xp_for_level(80)
	for item_id in ["steel_gladius", "steel_lorica", "steel_galea", "mirror_shield"]:
		sim.give_item(PLAYER, item_id, 1, "test", [])
		for slot in me.inventory.size:
			if me.inventory.slots[slot] and me.inventory.slots[slot]["item"] == item_id:
				sim.queue_item_action(PLAYER, "equip", {"slot": slot})
				break
		await seconds(0.7)
	player().destination = null
	player().global_position = Vector3(-318, 1, 324)
	await seconds(1.0)
	expect(await walk_to(Vector3(-328, 0, 340), 1.0, 40.0), "down the path to the ruins")
	main.get_node("CameraRig")._orbit(PI, 0.0)
	await seconds(0.5)
	await shot("ruins")
	main.get_node("CameraRig")._orbit(-PI, 0.0)
	var gorgons := get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.monster_id == "gorgon")
	expect(gorgons.size() == 4, "four gorgons (%d)" % gorgons.size())
	var target: Node = gorgons[3]
	for i in 300:
		if not target.combatant.is_alive():
			break
		if me.target_id == -1:
			player().attack(target.entity_id)
		me.hp = me.max_hp
		await seconds(0.5)
	expect(not target.combatant.is_alive(), "a gorgon falls")
	expect(me.remedy_boost("attack") == 0, "the mirror shield kept the gaze off")
