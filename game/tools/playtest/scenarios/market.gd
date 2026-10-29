extends "res://tools/playtest/scenario.gd"
## The forum market: through Lucius's menu, sell iron bars at today's price
## (which falls), buy something back by category, and see a Solitarius
## turned away.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var broker: Node3D = main.get_node("Rome/BrokerLucius")
	driver().sim.give_item(PLAYER, "iron_bar", 6, "test", [])
	driver().sim.give_item(PLAYER, "coins", 2000, "test", [])
	player().destination = null
	player().global_position = broker.global_position + Vector3(1.6, 0, 0)
	await seconds(1.0)

	var options: Array = WorldMenu.options_for(player(), broker)
	var labels := options.map(func(o): return o[0])
	expect(labels.any(func(l): return l.begins_with("Sell at the market")), "a sell entry (%s)" % [labels])
	expect(labels.any(func(l): return l.begins_with("Buy materials and other")), "a buy entry by category")
	var sales: Array = options.filter(func(o): return o[0].begins_with("Sell at the market"))[0][1].get_bound_arguments()[0]
	var iron: Array = sales.filter(func(o): return o[0].begins_with("Sell Iron bar"))
	expect(iron.size() == 1, "iron bars on the sell list")
	var price_before: int = driver().sim.market.price("iron_bar")
	var coins: int = me.inventory.count("coins")
	iron[0][1].call()
	await _wait_until(func(): return me.inventory.count("iron_bar") == 0, 15.0)
	expect(me.inventory.count("iron_bar") == 0, "sold the iron")
	expect(me.inventory.count("coins") > coins, "for coins")
	expect(driver().sim.market.price("iron_bar") < price_before, "and iron is cheaper now")

	options = WorldMenu.options_for(player(), broker)
	var materials: Array = options.filter(func(o): return o[0].begins_with("Buy materials and other"))[0][1].get_bound_arguments()[0]
	var bars: Array = materials.filter(func(o): return o[0].begins_with("Buy Iron bar"))
	expect(bars.size() == 1, "iron bars to buy back")
	bars[0][1].call()
	await _wait_until(func(): return me.inventory.count("iron_bar") > 0, 15.0)
	expect(me.inventory.count("iron_bar") == 1, "bought one back")
	await shot("broker")

	me.account_mode = "solitarius"
	var before: int = me.inventory.count("iron_bar")
	bars[0][1].call()
	await seconds(1.5)
	expect(me.inventory.count("iron_bar") == before, "a Solitarius can't buy here")


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
