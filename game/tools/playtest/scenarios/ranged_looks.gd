extends "res://tools/playtest/scenario.gd"
## Close-ups of the player holding each ranged weapon, mid-attack, for
## reviewing the bow and sling with --render.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.skills.xp["ranged"] = me.skills.xp_for_level(20)
	var rig: Node3D = main.get_node("CameraRig")
	# Face the player from the front-left (it faces +Z by default).
	rig._yaw = 0.7
	rig._pitch = deg_to_rad(-18.0)
	rig._apply_rotation()
	rig.get_node("SpringArm3D").spring_length = 4.5
	for item in ["hunting_bow", "composite_bow", "sling"]:
		driver().sim.give_item(PLAYER, item, 1, "test", [])
		driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of(item)})
		await seconds(0.8)
		expect(me.equipment.worn["weapon"] == item, "wearing %s" % item)
		await shot(item)
		player()._model.attack()
		await seconds(0.35)
		var expected: String = {"hunting_bow": "2H_Ranged_Shoot", "composite_bow": "2H_Ranged_Shoot", "sling": "Throw"}[item]
		expect(player()._model.current_animation() == expected, "%s plays %s (got %s)" % [item, expected, player()._model.current_animation()])
		await shot(item + "_attack")


func _slot_of(item_id: String) -> int:
	var slots: Array = driver().sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1
