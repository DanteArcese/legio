extends "res://tools/playtest/scenario.gd"
## Vipasca: take the south-east road to the silver mines, hear the picks and
## cicadas, mine silver in the pit, smelt it in town, and ride home.

const PLAYER := 1


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for skill in ["mining", "smithing"]:
		me.skills.xp[skill] = me.skills.xp_for_level(35)
	driver().sim.give_item(PLAYER, "iron_pickaxe", 1, "test", [])
	var road: Node3D = main.get_node("RoadToVipasca")
	expect(await route_to(road.global_position + Vector3(-1.2, 0, -2.0), 1.0, 120.0), "reached the south-east road")
	player().travel(road)
	await _wait_until(func(): return player().global_position.z > 300.0, 20.0)
	expect(player().global_position.z > 300.0, "the road leads to Vipasca")
	await seconds(3.0)
	expect(main.get_node("Sound").zone == "vipasca", "picks and cicadas (%s)" % main.get_node("Sound").zone)
	await shot("arrival")

	for waypoint in [Vector3(0, 0, 372), Vector3(-3, 0, 390)]:
		expect(await walk_to(waypoint, 1.0, 60.0), "walked to %s" % waypoint)
	await shot("pit")
	var rock: Node3D = main.get_node("Vipasca/Silver1")
	player().mine(rock)
	await _wait_until(func(): return me.inventory.count("silver_ore") > 0, 90.0)
	expect(me.inventory.count("silver_ore") > 0, "mined silver ore")
	var coal := get_tree().get_nodes_in_group("rocks").filter(func(r): return r.rock_type == "coal_rock")
	expect(coal.size() == 3, "three coal rocks in the pit (%d)" % coal.size())

	await walk_to(Vector3(0, 0, 372), 1.0, 60.0)
	expect(await walk_to(main.get_node("Vipasca/Furnace").global_position + Vector3(0, 0, 1.2), 0.4, 60.0), "at the furnace")
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "smelt", "recipe": "silver_bar", "count": 1})
	await _wait_until(func(): return me.inventory.count("silver_bar") > 0, 20.0)
	expect(me.inventory.count("silver_bar") > 0, "smelted a silver bar in town")
	await shot("town")

	var home: Node3D = main.get_node("Vipasca/RoadToFort")
	await walk_to(home.global_position + Vector3(0, 0, 2.0), 0.8, 60.0)
	player().travel(home)
	await _wait_until(func(): return player().global_position.z < 100.0, 20.0)
	expect(player().global_position.z < 100.0, "back on the overworld")


func _wait_until(condition: Callable, timeout: float) -> void:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await seconds(0.25)
		waited += 0.25
