extends "res://tools/playtest/scenario.gd"
## Loot labels stay out of the way: shown only near the player, capped at a
## few lines, and gold for valuable piles.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var sim: RefCounted = driver().sim
	var at := Vector3(-3, 0, 6)
	player().global_position = Vector3(-3, 1, 8)
	for item in ["bread", "copper_ore", "tin_ore", "raw_meat", "bronze_pugio"]:
		sim.give_item(PLAYER, item, 1, "test", [])
	for i in 5:
		sim.queue_item_action(PLAYER, "drop", {"slot": _first_slot_after_kit()})
		await seconds(0.7)
	var piles := get_tree().get_nodes_in_group("loot_piles")
	expect(piles.size() > 0, "dropped items are on the ground")
	await seconds(0.2)
	expect(piles.all(func(p): return p.is_label_shown()), "labels show up close")
	await shot("near")
	player().global_position = Vector3(-3, 1, -6)
	await seconds(0.3)
	expect(piles.all(func(p): return not p.is_label_shown()), "labels hide from afar")

	# A pile with an iron lorica in it is highlighted.
	sim.give_item(PLAYER, "iron_lorica", 1, "test", [])
	sim.queue_item_action(PLAYER, "drop", {"slot": _slot_of("iron_lorica")})
	await seconds(0.8)
	var lorica_pile: Node = null
	for pile in get_tree().get_nodes_in_group("loot_piles"):
		if pile.items.any(func(e): return e["item"] == "iron_lorica"):
			lorica_pile = pile
	expect(lorica_pile != null and lorica_pile.is_valuable(), "valuable pile highlighted")
	var bread_pile: Node = null
	for pile in get_tree().get_nodes_in_group("loot_piles"):
		if pile.items.size() == 1 and pile.items[0]["item"] == "bread":
			bread_pile = pile
	expect(bread_pile == null or not bread_pile.is_valuable(), "bread isn't")


## The last inventory slot holding something droppable (not coins or tools).
func _first_slot_after_kit() -> int:
	var slots: Array = driver().sim.get_combatant(PLAYER).inventory.slots
	for i in range(slots.size() - 1, -1, -1):
		if slots[i] and not (slots[i]["item"] in ["coins", "bronze_pickaxe", "hammer"]):
			return i
	return -1


func _slot_of(item_id: String) -> int:
	var slots: Array = driver().sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1
