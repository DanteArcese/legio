extends "res://tools/playtest/scenario.gd"
## The Portus Salis beach run: too hard below Athletics 30; then a lap of
## mast, hull, rope and net racks along the sand.

const PLAYER := 1
const OBSTACLES := ["BeachMast", "BeachHull", "BeachRope", "BeachNets"]


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.max_hp = 40
	me.hp = 40
	var first: Node3D = main.get_node("PortusSalis/BeachMast")
	player().destination = null
	player().global_position = first.global_position + Vector3(-1.0, 1, 0)
	await seconds(1.0)
	player().cross(first)
	await seconds(2.0)
	expect(not player().is_crossing() and me.obstacle.is_empty(), "too low at Athletics 1")

	me.skills.xp["athletics"] = me.skills.xp_for_level(99)
	for name in OBSTACLES:
		var obstacle: Node3D = main.get_node("PortusSalis/" + name)
		await route_to(obstacle.global_position + Vector3(-0.8, 0, 0), 0.5, 30.0)
		var before: float = me.skills.xp["athletics"]
		player().cross(obstacle)
		await _wait_until(func(): return player().is_crossing(), 20.0)
		expect(player().is_crossing(), "started the %s" % name)
		await seconds(1.0)
		if name == "BeachRope":
			await shot("rope")
		await _wait_until(func(): return not player().is_crossing() and me.obstacle.is_empty(), 20.0)
		await seconds(0.3)
		expect(me.skills.xp["athletics"] > before, "%s gives XP" % name)
	expect(me.laps == 1, "a lap of the beach run (%d)" % me.laps)


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
