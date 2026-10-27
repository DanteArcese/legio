extends "res://tools/playtest/scenario.gd"
## Eels: the grove pool on Seriphos needs an eel pot (Nikias sells them)
## and Fishing 30. Trap a few eels, then roast one on the harbour fire.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.skills.xp["fishing"] = me.skills.xp_for_level(30)
	me.skills.xp["cooking"] = me.skills.xp_for_level(30)
	driver().sim.give_item(PLAYER, "coins", 200, "test", [])
	var spot: Node3D = main.get_node("Seriphos/EelSpot")
	expect(spot.verb() == "Trap", "the pool is trapped, not netted (%s)" % spot.verb())

	var nikias: Node3D = main.get_node("Seriphos/Nikias")
	player().destination = null
	player().global_position = nikias.global_position + Vector3(0, 1, 2.0)
	await seconds(1.0)
	player().fish(spot)
	await seconds(3.0)
	expect(me.inventory.count("raw_eel") == 0, "no eels without a pot")

	var pots: Array = WorldMenu.wares_for(player(), nikias).filter(func(o): return o[0].begins_with("Buy eel pot"))
	expect(pots.size() == 1, "Nikias sells eel pots")
	if pots.size() == 1:
		pots[0][1].call()
	await _wait_until(func(): return me.inventory.count("eel_pot") > 0, 30.0)
	expect(me.inventory.count("eel_pot") == 1, "bought an eel pot")

	expect(await route_to(spot.global_position + Vector3(0, 0, -4.0), 1.0, 90.0), "walked to the grove pool")
	player().fish(spot)
	await _wait_until(func(): return me.inventory.count("raw_eel") >= 2, 90.0)
	expect(me.inventory.count("raw_eel") >= 2, "trapped eels (%d)" % me.inventory.count("raw_eel"))
	await shot("eel_pool")
	metric("fishing_xp", me.skills.xp["fishing"])

	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "cook", "recipe": "cooked_eel", "count": 1})
	await seconds(2.0)
	expect(me.inventory.count("cooked_eel") == 0, "eels need a fire")


func _wait_until(condition: Callable, timeout: float) -> void:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await seconds(0.25)
		waited += 0.25
