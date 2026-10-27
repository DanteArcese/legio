extends "res://tools/playtest/scenario.gd"
## Basilisks at the mouth of Vipasca's deep gallery: a hunter with a mirror
## shield kills one without their limbs stiffening.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for skill in ["attack", "strength", "defence", "vitality", "slayer"]:
		me.skills.xp[skill] = me.skills.xp_for_level(60)
	for item_id in ["steel_gladius", "mirror_shield"]:
		driver().sim.give_item(PLAYER, item_id, 1, "test", [])
		driver().sim.queue_item_action(PLAYER, "equip", {"slot": 0})
		await seconds(0.7)
	expect(me.equipment.worn["shield"] == "mirror_shield", "holding the mirror shield")
	player().destination = null
	player().global_position = Vector3(-20, 1, 424)
	await seconds(1.0)
	var basilisks := get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.monster_id == "basilisk")
	expect(basilisks.size() == 4, "four basilisks at the gallery (%d)" % basilisks.size())
	main.get_node("CameraRig")._orbit(PI, 0.0)
	await seconds(0.5)
	await shot("gallery")
	main.get_node("CameraRig")._orbit(-PI, 0.0)
	var target: Node = basilisks[0]
	for i in 240:
		if not target.combatant.is_alive():
			break
		if me.target_id == -1:
			driver().sim.queue_attack(PLAYER, target.entity_id)
		me.hp = me.max_hp
		await seconds(0.5)
	expect(count_events("death", {"id": target.entity_id}) > 0, "killed a basilisk")
	expect(me.remedy_boost("attack") == 0 and me.remedy_boost("defence") == 0, "no drain with the mirror shield")
