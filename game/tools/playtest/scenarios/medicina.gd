extends "res://tools/playtest/scenario.gd"
## Medicina: buy wine and a mortar and pestle from the sacerdos, mix mint
## into a tonic from the inventory's Mix option, drink it, and see the
## boost on the HUD.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	driver().sim.give_item(PLAYER, "coins", 100, "test", [])
	driver().sim.give_item(PLAYER, "mint", 2, "test", [])
	var sacerdos: Node3D = main.get_node("Sacerdos")
	for label in ["Buy wine", "Buy mortar and pestle"]:
		var option: Array = WorldMenu.options_for(player(), sacerdos).filter(func(o): return o[0].begins_with(label))
		expect(option.size() == 1, "the sacerdos sells: %s" % label)
		if option.size() == 1:
			option[0][1].call()
			await seconds(3.0)
	expect(me.inventory.count("mortar_and_pestle") == 1 and me.inventory.count("wine") == 1, "bought wine and a pestle")

	var game_ui: Node = main.get_node("GameUi")
	var options: Array = game_ui._inventory_options(_slot_of("mint")).map(func(o): return o[0])
	expect(options.has("Mix"), "mint has a Mix option (%s)" % [options])
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "medicina", "recipe": "mint_tonic", "count": 1})
	await action_done()
	expect(me.inventory.count("mint_tonic") == 1, "mixed a mint tonic")
	var drink: Array = game_ui._inventory_options(_slot_of("mint_tonic")).filter(func(o): return o[0] == "Drink")
	expect(drink.size() == 1, "the tonic can be drunk")
	if drink.size() == 1:
		drink[0][1].call()
	await seconds(1.0)
	expect(me.remedy_boost("attack") > 0, "attack boosted")
	expect("Atk 1+" in main.get_node("Hud")._status.text, "the HUD shows the boost")
	await shot("boosted")


func _slot_of(item_id: String) -> int:
	var slots: Array = driver().sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1
