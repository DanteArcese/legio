extends "res://tests/test_case.gd"

const ItemContainer := preload("res://scripts/sim/item_container.gd")


func test_unstackable_items_take_one_slot_each() -> void:
	var inv := ItemContainer.new(28)
	check_eq(inv.add("copper_ore", 3), 3, "added")
	check_eq(inv.free_slots(), 25, "free slots")
	check_eq(inv.count("copper_ore"), 3, "count")


func test_stackable_items_share_a_slot() -> void:
	var inv := ItemContainer.new(28)
	inv.add("coins", 10)
	inv.add("coins", 15)
	check_eq(inv.free_slots(), 27, "one slot")
	check_eq(inv.count("coins"), 25, "count")


func test_full_inventory_adds_only_what_fits() -> void:
	var inv := ItemContainer.new(3)
	check_eq(inv.add("tin_ore", 5), 3, "partial")
	check_eq(inv.add("coins", 5), 0, "no slot for a new stack")
	inv.remove("tin_ore", 1)
	check_eq(inv.add("coins", 5), 5, "now it fits")
	check_eq(inv.add("coins", 5), 5, "existing stack always fits")


func test_bank_stacks_everything() -> void:
	var bank := ItemContainer.new(10, true)
	bank.add("copper_ore", 50)
	check_eq(bank.free_slots(), 9, "one slot")
	check_eq(bank.count("copper_ore"), 50, "count")


func test_remove_takes_from_later_slots_first_and_clears_empties() -> void:
	var inv := ItemContainer.new(5)
	inv.add("iron_ore", 3)
	check_eq(inv.remove("iron_ore", 2), 2, "removed")
	check(inv.slots[0] != null and inv.slots[1] == null and inv.slots[2] == null, "kept first slot")
	check_eq(inv.remove("iron_ore", 9), 1, "only what exists")
	check(inv.is_empty(), "empty")


func test_round_trips_through_arrays() -> void:
	var inv := ItemContainer.new(4)
	inv.add("coins", 7)
	inv.add("bread", 1)
	var copy := ItemContainer.new(4)
	copy.load_array(inv.to_array())
	check_eq(copy.to_array(), inv.to_array(), "same slots")
