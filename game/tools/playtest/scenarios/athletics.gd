extends "res://tools/playtest/scenario.gd"
## A lap of the training course east of the fort: log, wall, rope swing,
## hurdles. Each crossing plays out over its ticks and ends at the far side.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.skills.xp["athletics"] = me.skills.xp_for_level(50)
	var obstacles := ["LogBalance", "PalisadeWall", "RopeSwing", "Hurdles"]
	await route_to(main.get_node("AthleticsCourse/LogBalance").global_position + Vector3(0, 0, -1.0), 0.5, 120.0)
	for name in obstacles:
		var obstacle: Node3D = main.get_node("AthleticsCourse/" + name)
		var before: float = me.skills.xp["athletics"]
		player().cross(obstacle)
		await _wait_until(func(): return player().is_crossing(), 20.0)
		expect(player().is_crossing(), "started the %s" % name)
		await seconds(1.0)
		if name == "PalisadeWall":
			await shot("wall")
		await _wait_until(func(): return not player().is_crossing() and me.obstacle.is_empty(), 20.0)
		await seconds(0.3)
		var end: Vector3 = obstacle.end_position()
		expect(Vector2(player().global_position.x, player().global_position.z).distance_to(Vector2(end.x, end.z)) < 0.8,
			"ended at the far side of the %s (%s vs %s)" % [name, player().global_position, end])
		expect(me.skills.xp["athletics"] > before, "%s gives XP" % name)
	expect(me.laps == 1, "one lap (%d)" % me.laps)
	await shot("lap")


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
