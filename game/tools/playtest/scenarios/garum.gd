extends "res://tools/playtest/scenario.gd"
## Garum: buy salt from the Gaulish merchant, then ferment anchovies at the
## vat by the pond.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.skills.xp["cooking"] = me.skills.xp_for_level(20)
	driver().sim.give_item(PLAYER, "coins", 100, "test", [])
	driver().sim.give_item(PLAYER, "raw_anchovy", 8, "test", [])
	var merchant: Node3D = main.get_node("Forum/Merchant")
	var buy_salt: Array = WorldMenu.wares_for(player(), merchant).filter(func(o): return o[0].begins_with("Buy salt"))
	expect(buy_salt.size() == 1, "the merchant sells salt")
	if buy_salt.size() == 1:
		buy_salt[0][1].call()
	await _wait_until(func(): return me.inventory.count("salt") == 20, 30.0)
	expect(me.inventory.count("salt") == 20, "bought 20 salt")

	var vat: Node3D = main.get_node("Fishing/GarumVat")
	for waypoint in [Vector3(0, 0, 22), Vector3(12.5, 0, 25.5), Vector3(12.5, 0, 32.9)]:
		await walk_to(waypoint, 0.8, 60.0)
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "garum", "recipe": "garum", "count": 2})
	await _wait_until(func(): return me.inventory.count("garum") == 2, 20.0)
	expect(me.inventory.count("garum") == 2, "fermented two amphorae of garum (%d)" % me.inventory.count("garum"))
	await shot("garum_vat")


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
