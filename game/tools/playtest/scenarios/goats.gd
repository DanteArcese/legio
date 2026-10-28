extends "res://tools/playtest/scenario.gd"
## Wild goats: a new player walks out to the pasture north-east of the fort and
## kills a goat; goats don't start fights.

const PLAYER := 1


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	await route_to(Vector3(30, 0, -12), 1.0, 120.0)
	var goats := get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.monster_id == "goat")
	expect(goats.size() == 5, "five goats in the pasture (%d)" % goats.size())
	await seconds(3.0)
	expect(goats.all(func(g): return g.combatant.target_id != PLAYER), "goats don't start fights")
	await shot("pasture")
	var goat: Node = goats[0]
	var bones: int = me.inventory.count("bones")
	player().attack(goat.entity_id)
	await _wait_until(func(): return not goat.combatant.is_alive() or not me.is_alive(), 60.0)
	expect(not goat.combatant.is_alive(), "a combat-2 player kills a goat")
	expect(me.is_alive(), "and lives")
	metric("hp_left", me.hp)


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
