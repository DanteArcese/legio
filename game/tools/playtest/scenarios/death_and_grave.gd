extends "res://tools/playtest/scenario.gd"
## A player dies to a latro, respawns at spawn, walks back to the grave, and
## loots it. (Expiry and libitinarius reclaim are covered by unit tests.)

const PLAYER := 1


func run() -> void:
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	driver().sim.give_item(PLAYER, "bronze_galea", 1, "test", [])
	driver().sim.give_item(PLAYER, "copper_ore", 3, "test", [])
	var latro := _entity("latro")
	# Stand next to the latro and let it win.
	me.hp = 2
	await route_to(latro.body().global_position + Vector3(1.2, 0, 0), 0.5)
	await _wait_until(func(): return count_events("death", {"id": PLAYER}) > 0, 60.0)
	expect(count_events("death", {"id": PLAYER}) == 1, "player died")
	var grave: Dictionary = driver().sim.grave_of(PLAYER)
	expect(not grave.is_empty(), "grave created")
	await shot("dead")
	await _wait_until(func(): return me.is_alive(), 10.0)
	await seconds(0.5)
	expect(player().global_position.distance_to(Vector3(0, 1, 2)) < 1.5, "respawned at spawn")
	metric("kept", me.inventory.slots.filter(func(s): return s != null).size())
	metric("grave_items", grave.get("items", []).size())

	# Walk back (the latro may chase; that's part of the test) and loot.
	await route_to(grave["position"], 0.8)
	await shot("at_grave")
	await press("interact")
	await seconds(1.0)
	expect(driver().sim.grave_of(PLAYER).is_empty() or count_events("death", {"id": PLAYER}) > 1, "grave looted (or died again trying)")
	metric("deaths", count_events("death", {"id": PLAYER}))


func _entity(monster_id: String) -> Node:
	for entity in get_tree().get_nodes_in_group("sim_entities"):
		if entity.monster_id == monster_id:
			return entity
	return null


func _wait_until(condition: Callable, timeout: float) -> void:
	var frames := ceili(timeout * Engine.physics_ticks_per_second)
	for i in frames:
		if condition.call():
			return
		await get_tree().physics_frame
