extends RefCounted
## A fixed number of item slots: the inventory (28) or the bank.
## Stackable items share one slot. The bank stacks everything.

const ContentDB := preload("res://scripts/content/content_db.gd")

var size: int
var stack_all: bool
## Each slot is null or {"item": id, "quantity": n}.
var slots: Array = []


func _init(p_size: int, p_stack_all := false) -> void:
	size = p_size
	stack_all = p_stack_all
	slots.resize(size)


func stacks(item_id: String) -> bool:
	return stack_all or ContentDB.item(item_id).get("stackable", false)


func count(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if slot and slot["item"] == item_id:
			total += slot["quantity"]
	return total


func free_slots() -> int:
	return slots.count(null)


func is_empty() -> bool:
	return free_slots() == size


## How many of an item would fit right now.
func space_for(item_id: String, quantity: int) -> int:
	if stacks(item_id):
		return quantity if _find(item_id) != -1 or free_slots() > 0 else 0
	return mini(quantity, free_slots())


## Adds up to quantity and returns how many were added.
func add(item_id: String, quantity: int) -> int:
	var added := space_for(item_id, quantity)
	if added <= 0:
		return 0
	if stacks(item_id):
		var index := _find(item_id)
		if index == -1:
			slots[slots.find(null)] = {"item": item_id, "quantity": added}
		else:
			slots[index]["quantity"] += added
	else:
		for i in added:
			slots[slots.find(null)] = {"item": item_id, "quantity": 1}
	return added


## Removes up to quantity and returns how many were removed.
func remove(item_id: String, quantity: int) -> int:
	var removed := 0
	for i in range(size - 1, -1, -1):
		var slot: Variant = slots[i]
		if removed >= quantity or slot == null or slot["item"] != item_id:
			continue
		var take := mini(slot["quantity"], quantity - removed)
		slot["quantity"] -= take
		removed += take
		if slot["quantity"] == 0:
			slots[i] = null
	return removed


## Takes a whole slot out and returns it (or null).
func take_slot(index: int) -> Variant:
	var slot: Variant = slots[index] if index >= 0 and index < size else null
	if slot:
		slots[index] = null
	return slot


func to_array() -> Array:
	return slots.map(func(slot): return slot.duplicate() if slot else null)


func load_array(data: Array) -> void:
	for i in mini(size, data.size()):
		slots[i] = data[i].duplicate() if data[i] else null


func _find(item_id: String) -> int:
	for i in size:
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1
