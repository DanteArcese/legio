extends "res://tools/playtest/scenario.gd"
## Selling through a shopkeeper's menu: the Sell entry opens a list of what
## they'll buy from the pack, and choosing one pays for all of it.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")
const Items := preload("res://scripts/sim/items.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	driver().sim.give_item(PLAYER, "pearl", 1, "test", [])
	driver().sim.give_item(PLAYER, "wolf_pelt", 2, "test", [])
	var merchant: Node3D = main.get_node("Forum/Merchant")
	var sell: Array = WorldMenu.options_for(player(), merchant).filter(func(o): return o[0].begins_with("Sell ("))
	expect(sell.size() == 1, "the merchant's menu has a Sell entry")
	if sell.is_empty():
		return
	sell[0][1].call()
	await seconds(0.3)
	var game_ui: Node = main.get_node("GameUi")
	expect(game_ui.is_menu_open(), "it opens the list of things to sell")
	await shot("sell_menu")
	game_ui._menu.hide()
	var pearl: Array = WorldMenu.sales_for(player(), merchant).filter(func(o): return o[0].begins_with("Sell pearl"))
	expect(pearl.size() == 1, "the merchant will take the pearl")
	var coins_before: int = me.inventory.count("coins")
	pearl[0][1].call()
	await _wait_until(func(): return me.inventory.count("pearl") == 0, 30.0)
	expect(me.inventory.count("coins") - coins_before == Items.sell_price("gallic_merchant", "pearl"), "paid for the pearl")


func _wait_until(condition: Callable, timeout: float) -> void:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await seconds(0.25)
		waited += 0.25
