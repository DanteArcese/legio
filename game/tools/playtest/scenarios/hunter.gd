extends "res://tools/playtest/scenario.gd"
## Hunter: buy a box trap from Aulus, set it at a hare burrow south of the
## fields, wait for a catch, and collect it.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var aulus: Node3D = main.get_node("VenatorAulus")
	player().buy(aulus, "box_trap")
	await _wait_until(func(): return me.inventory.count("box_trap") == 1, 30.0)
	expect(me.inventory.count("box_trap") == 1, "bought a box trap")

	var burrow: Node3D = main.get_node("HuntingGrounds/HareBurrow1")
	await route_to(Vector3(0, 0, 24), 1.0, 90.0)
	await walk_to(burrow.global_position + Vector3(-1.4, 0, 0), 0.4, 60.0)
	var options: Array = WorldMenu.options_for(player(), burrow).map(func(o): return o[0])
	expect(options.has("Set a box trap at the hare burrow"), "the burrow offers to set a trap (%s)" % [options])
	player().use_trap_spot(burrow)
	await _wait_until(func(): return me.inventory.count("box_trap") == 0, 10.0)
	expect(burrow._trap.visible, "the trap shows at the burrow")
	await shot("trap_set")
	await _wait_until(func(): return driver().sim.hunter.spots[burrow.spot_id]["trap"].get("state") == "caught", 180.0)
	expect(driver().sim.hunter.spots[burrow.spot_id]["trap"].get("state") == "caught", "something walked in")
	player().use_trap_spot(burrow)
	await _wait_until(func(): return me.inventory.count("hare_pelt") == 1, 10.0)
	expect(me.inventory.count("hare_pelt") == 1 and me.inventory.count("box_trap") == 1, "collected a hare pelt and the trap")
	expect(not burrow._trap.visible, "the trap is gone from the burrow")
	metric("hunter_xp", me.skills.xp["hunter"])


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
