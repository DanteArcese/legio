extends "res://tools/playtest/scenario.gd"
## The villa estate: build an olive press in the press house and press oil
## from olives, then hire a steward, and (with his books set back five
## hours) collect the amphorae he filled while you were away.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.quests["decurio"] = {"step": 3, "progress": 0, "done": true}
	me.villa_owned = true
	me.skills.xp["engineering"] = me.skills.xp_for_level(40)
	me.skills.xp["cooking"] = me.skills.xp_for_level(30)
	me.inventory.remove("coins", me.inventory.count("coins"))
	driver().sim.give_item(PLAYER, "hammer", 1, "test", [])
	for item in ["oak_plank", "iron_bar"]:
		var needed: int = ContentDB.furniture("olive_press")["materials"].filter(func(m): return m["item"] == item)[0]["quantity"]
		driver().sim.give_item(PLAYER, item, needed, "test", [])
	player()._arrive_through(main.get_node("RoadToVilla"))
	await seconds(0.5)
	expect(player().global_position.x > 300.0, "at the villa")

	var press_floor: Node3D = main.get_node("Villa/Hotspot_press_1")
	_choose(press_floor, "Build olive press")
	await _wait_until(func(): return press_floor.furniture == "olive_press", 40.0)
	expect(press_floor.furniture == "olive_press", "built an olive press")
	driver().sim.give_item(PLAYER, "olives", 8, "test", [])
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "press_oil", "recipe": "olive_oil", "count": 2})
	await action_done()
	expect(me.inventory.count("olive_oil") == 2, "pressed two amphorae of oil (%d)" % me.inventory.count("olive_oil"))

	driver().sim.give_item(PLAYER, "oak_plank", 4, "test", [])
	driver().sim.give_item(PLAYER, "coins", 1000, "test", [])
	var office: Node3D = main.get_node("Villa/Hotspot_office")
	_choose(office, "Build steward's desk")
	await _wait_until(func(): return office.furniture == "steward_desk", 40.0)
	expect(office.furniture == "steward_desk", "hired a steward")
	await seconds(0.5)
	me.steward_since -= 5 * 3600.0
	_choose(office._built, "Collect from the steward")
	await _wait_until(func(): return me.inventory.count("olive_oil") > 2, 30.0)
	expect(me.inventory.count("olive_oil") == 4, "the steward handed over two more (%d)" % me.inventory.count("olive_oil"))
	var rig: Node3D = main.get_node("CameraRig")
	rig._yaw = PI * 0.75
	rig._apply_rotation()
	await seconds(0.5)
	await shot("steward")


func _choose(node: Node, prefix: String) -> void:
	var options: Array = WorldMenu.options_for(player(), node).filter(func(o): return o[0].begins_with(prefix))
	expect(options.size() >= 1, "%s offers: %s" % [node.name, prefix])
	if not options.is_empty():
		options[0][1].call()


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
