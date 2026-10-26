extends "res://tools/playtest/scenario.gd"
## The villa: the road is closed to a non-citizen; a citizen buys a villa
## from the land surveyor, saws planks at the sawpit, and builds working
## furniture: a campfire that cooks, a herb bed to plant, and a waystone
## to Portus Salis.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var road: Node3D = main.get_node("RoadToVilla")
	player()._arrive_through(road)
	await seconds(0.3)
	expect(player().global_position.x < 100.0, "the villa road is closed to a non-citizen")

	me.quests["decurio"] = {"step": 3, "progress": 0, "done": true}
	driver().sim.give_item(PLAYER, "coins", 6000, "test", [])
	var surveyor: Node3D = main.get_node("Forum/LandSurveyor")
	_choose(surveyor, "Buy a villa")
	await _wait_until(func(): return me.villa_owned, 30.0)
	expect(me.villa_owned, "bought a villa")

	driver().sim.give_item(PLAYER, "logs", 8, "test", [])
	var sawpit: Node3D = main.get_node("Smithy/Sawpit")
	await route_to(sawpit.global_position + Vector3(0, 0, 1.4), 0.4, 90.0)
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "saw", "recipe": "plank", "count": 8})
	await action_done()
	expect(me.inventory.count("plank") == 8, "sawed eight planks (%d)" % me.inventory.count("plank"))

	player()._arrive_through(road)
	await seconds(0.5)
	expect(player().global_position.x > 300.0, "the road leads a villa owner home")
	await shot("villa_arrival")

	var hearth: Node3D = main.get_node("Villa/Hotspot_hearth")
	_choose(hearth, "Build campfire")
	await _wait_until(func(): return hearth.furniture == "villa_campfire", 30.0)
	expect(hearth.furniture == "villa_campfire", "built a campfire on the hearth")
	driver().sim.give_item(PLAYER, "raw_sardine", 1, "test", [])
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "cook", "recipe": "cooked_sardine", "count": 1})
	await action_done()
	expect(me.inventory.count("cooked_sardine") + me.inventory.count("burnt_food") == 1, "cooked on the villa's own fire")

	var garden: Node3D = main.get_node("Villa/Hotspot_garden_1")
	_choose(garden, "Build herb bed")
	await _wait_until(func(): return garden.furniture == "herb_bed", 30.0)
	expect(garden.furniture == "herb_bed", "built a herb bed")
	driver().sim.give_item(PLAYER, "trowel", 1, "test", [])
	driver().sim.give_item(PLAYER, "mint_seed", 1, "test", [])
	var bed: Node3D = garden._built
	_choose(bed, "Plant mint seed")
	await _wait_until(func(): return bed.crop == "mint", 20.0)
	expect(bed.crop == "mint", "planted mint in the villa garden")
	await shot("villa_built")

	me.skills.xp["engineering"] = me.skills.xp_for_level(40)
	driver().sim.give_item(PLAYER, "iron_bar", 4, "test", [])
	driver().sim.give_item(PLAYER, "oak_plank", 6, "test", [])
	var waystone: Node3D = main.get_node("Villa/Hotspot_waystone")
	_choose(waystone, "Build waystone")
	await _wait_until(func(): return waystone.furniture == "waystone", 30.0)
	_choose(waystone._built, "Travel to Portus Salis")
	await _wait_until(func(): return player().global_position.x < -250.0, 30.0)
	expect(player().global_position.x < -250.0, "the waystone leads to Portus Salis")


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
