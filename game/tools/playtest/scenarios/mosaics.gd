extends "res://tools/playtest/scenario.gd"
## Marble and mosaics: quarry Parian marble on Seriphos, carve it into
## tesserae with a chisel, lay a mosaic floor in the villa courtyard, and
## rest on it.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.quests["decurio"] = {"step": 3, "progress": 0, "done": true}
	me.villa_owned = true
	for skill in ["mining", "crafting", "engineering"]:
		me.skills.xp[skill] = me.skills.xp_for_level(50)
	driver().sim.give_item(PLAYER, "steel_pickaxe", 1, "test", [])
	var rock: Node3D = main.get_node("Seriphos/Marble1")
	player().destination = null
	player().global_position = rock.global_position + Vector3(0, 1, 1.5)
	await seconds(1.0)
	_choose(rock, "Mine")
	await _wait_until(func(): return me.inventory.count("marble_block") > 0, 60.0)
	expect(me.inventory.count("marble_block") >= 1, "quarried a block of marble")
	await shot("quarry")

	driver().sim.give_item(PLAYER, "chisel", 1, "test", [])
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "masonry", "recipe": "tesserae", "count": 1})
	await _wait_until(func(): return me.inventory.count("tesserae") > 0, 20.0)
	expect(me.inventory.count("tesserae") == 25, "carved 25 tesserae")

	driver().sim.give_item(PLAYER, "hammer", 1, "test", [])
	driver().sim.give_item(PLAYER, "tesserae", 125, "test", [])
	driver().sim.give_item(PLAYER, "oak_plank", 2, "test", [])
	player()._arrive_through(main.get_node("RoadToVilla"))
	await seconds(0.5)
	var atrium: Node3D = main.get_node("Villa/Hotspot_atrium")
	_choose(atrium, "Build mosaic floor")
	await _wait_until(func(): return atrium.furniture == "mosaic_floor", 40.0)
	expect(atrium.furniture == "mosaic_floor", "laid a mosaic floor")
	_choose(atrium, "Rest on the mosaic floor")
	await _wait_until(func(): return me.rested_until > driver().sim.tick, 20.0)
	expect(me.rested_until > driver().sim.tick, "rested on the mosaic")
	var rig: Node3D = main.get_node("CameraRig")
	rig._pitch = deg_to_rad(-55.0)
	rig._apply_rotation()
	rig.get_node("SpringArm3D").spring_length = 9.0
	await seconds(0.5)
	await shot("mosaic")


func _choose(node: Node, prefix: String) -> void:
	var options: Array = WorldMenu.options_for(player(), node).filter(func(o): return o[0].begins_with(prefix))
	expect(options.size() >= 1, "%s offers: %s (%s)" % [node.name, prefix, WorldMenu.options_for(player(), node).map(func(o): return o[0])])
	if not options.is_empty():
		options[0][1].call()


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
