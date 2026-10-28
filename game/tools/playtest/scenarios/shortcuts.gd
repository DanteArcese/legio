extends "res://tools/playtest/scenario.gd"
## Shortcuts: a new player can't climb the fort's west wall; at Athletics
## 10 they go over it to the grove side and back in.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.max_hp = 30
	me.hp = 30
	var out: Node3D = main.get_node("ShortcutWestOut")
	await route_to(out.global_position + Vector3(1.0, 0, 0), 0.5, 90.0)
	_choose(out, "Climb over")
	await seconds(3.0)
	expect(player().global_position.x > -20.0, "too low to climb at Athletics 1")

	me.skills.xp["athletics"] = me.skills.xp_for_level(99)
	_choose(out, "Climb over")
	await _wait_until(func(): return player().global_position.x < -21.0 and not player().is_crossing(), 20.0)
	expect(player().global_position.x < -21.0, "over the wall to the grove side")
	await shot("over")
	expect(me.laps == 0, "no lap credit for a shortcut")

	var back: Node3D = main.get_node("ShortcutWestIn")
	_choose(back, "Climb over")
	await _wait_until(func(): return player().global_position.x > -19.0 and not player().is_crossing(), 20.0)
	expect(player().global_position.x > -19.0, "and back into the fort")


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
