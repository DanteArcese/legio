extends "res://tools/playtest/scenario.gd"
## Aulus has Slayer options and a long list of wares: the wares fold into a
## Trade entry that opens them as their own menu, and buying from it works.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.slayer_task = {"monster": "wolf", "remaining": 20, "total": 20, "venator": "aulus"}
	driver().sim.give_item(PLAYER, "coins", 50, "test", [])
	var aulus: Node3D = main.get_node("VenatorAulus")
	var options: Array = WorldMenu.options_for(player(), aulus)
	var labels: Array = options.map(func(o): return o[0])
	metric("menu", labels)
	expect(labels.size() <= WorldMenu.MAX_MENU_ENTRIES, "short enough (%d)" % labels.size())
	expect(not labels.any(func(l): return l.begins_with("Buy ")), "no wares inline")
	var trade: Array = options.filter(func(o): return o[0].begins_with("Trade ("))
	expect(trade.size() == 1, "a Trade entry")
	if trade.is_empty():
		return
	trade[0][1].call()
	await seconds(0.3)
	var game_ui: Node = main.get_node("GameUi")
	expect(game_ui.is_menu_open(), "the wares open as a menu")
	expect(game_ui._menu.item_count == ContentDB.shop("aulus")["offers"].size(), "listing every ware (%d)" % game_ui._menu.item_count)
	await shot("trade")
	var needle: Array = WorldMenu.wares_for(player(), aulus).filter(func(o): return o[0].begins_with("Buy needle"))
	game_ui._menu.hide()
	needle[0][1].call()
	await _wait_until(func(): return me.inventory.count("needle") > 0, 30.0)
	expect(me.inventory.count("needle") == 1, "bought a needle from the submenu")


func _wait_until(condition: Callable, timeout: float) -> void:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await seconds(0.25)
		waited += 0.25
