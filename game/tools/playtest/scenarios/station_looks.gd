extends "res://tools/playtest/scenario.gd"
## Skilling tools and station models: the pickaxe shows in hand while
## mining, the weapon comes back after, and the smithy's stations stand in
## a row by the forge.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var rock: Node3D = main.get_node("Quarry/Copper1")
	await route_to(rock.global_position + Vector3(-1.4, 0, 0), 0.4, 90.0)
	player().mine(rock)
	await _wait_until(func(): return not me.skill_action.is_empty(), 10.0)
	await seconds(0.6)
	expect(player()._model._tool == "kenney:survival/tool-pickaxe", "holding a pickaxe while mining (%s)" % player()._model._tool)
	await shot("mining")
	await _wait_until(func(): return me.skill_action.is_empty(), 30.0)
	await seconds(0.4)
	expect(player()._model._tool == "", "the pickaxe goes away after")

	var anvil: Node3D = main.get_node("Smithy/Anvil")
	await route_to(anvil.global_position + Vector3(0, 0, 3.5), 0.5, 90.0)
	await seconds(0.5)
	await shot("smithy")


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
