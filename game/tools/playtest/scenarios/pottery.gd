extends "res://tools/playtest/scenario.gd"
## Pottery: dig clay by the pond, throw pots on the wheel in the potter's
## yard beside it, and fire them in the kiln.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	driver().sim.give_item(PLAYER, "bronze_pickaxe", 1, "test", [])
	var clay: Node3D = main.get_node("Quarry/Clay1")
	expect(await route_to(clay.global_position + Vector3(-1.4, 0, 0), 0.8, 120.0), "reached the clay by the pond")
	for i in 240:
		if me.inventory.count("clay") >= 3:
			break
		if me.skill_action.is_empty():
			player().mine(clay)
		await seconds(0.5)
	expect(me.inventory.count("clay") >= 3, "dug clay (%d)" % me.inventory.count("clay"))
	driver().sim.queue_item_action(PLAYER, "stop_action")
	var wheel: Node3D = main.get_node("Smithy/PottersWheel")
	var reached := await route_to(wheel.global_position + Vector3(-1.3, 0, 0), 0.9, 60.0)
	expect(reached, "walked to the potter's wheel (ended at %s)" % player().global_position)
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "throw", "recipe": "unfired_pot", "count": 3})
	await _wait_until(func(): return me.inventory.count("unfired_pot") >= 3, 30.0)
	expect(me.inventory.count("unfired_pot") >= 3, "threw pots")
	var kiln: Node3D = main.get_node("Smithy/Kiln")
	expect(await walk_to(kiln.global_position + Vector3(-1.5, 0, 0), 0.9, 20.0), "at the kiln")
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "kiln", "recipe": "clay_pot", "count": 3})
	await _wait_until(func(): return me.inventory.count("clay_pot") >= 3, 30.0)
	expect(me.inventory.count("clay_pot") >= 3, "fired pots")
	await shot("kiln")


func _wait_until(condition: Callable, timeout: float) -> void:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await seconds(0.25)
		waited += 0.25
