extends "res://tools/playtest/scenario.gd"
## Ursa the Venatrix in the yard inside the limes: an experienced hunter
## takes a frontier contract from her, and a fresh one is turned away.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var ursa: Node3D = main.get_node("Frontier/VenatrixUrsa")
	player().destination = null
	player().global_position = ursa.global_position + Vector3(0, 0, 2.0)
	await seconds(1.0)
	await press("interact")
	await seconds(1.0)
	expect(me.slayer_task.is_empty(), "a fresh character gets nothing")

	for skill in ["attack", "strength", "defence", "vitality", "slayer"]:
		me.skills.xp[skill] = me.skills.xp_for_level(55)
	await press("interact")
	await seconds(1.0)
	expect(me.slayer_task.get("venator", "") == "ursa", "Ursa gives a contract")
	metric("task", "%d %s" % [me.slayer_task.get("total", 0), me.slayer_task.get("monster", "?")])
	main.get_node("CameraRig")._orbit(PI, 0.0)
	await seconds(0.5)
	await shot("ursa")
