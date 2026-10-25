extends RefCounted
## Rules for what a player keeps and loses on death, and what the
## libitinarii (undertakers) charge to return lost items.

const ContentDB := preload("res://scripts/content/content_db.gd")

const KEPT_ON_DEATH := 3
## Fee is this fraction of the items' total value, rounded up.
const RECLAIM_FEE_RATE := 0.1


## Splits a player's carried and worn items into what they keep and what
## they lose. Each unstackable item counts once; a stack counts once at its
## unit value, so a big coin stack is never "most valuable".
## Returns {"kept_worn": [slot...], "kept_inventory": [{item, quantity}...],
## "lost": [{item, quantity}...]}.
static func split(inventory: RefCounted, equipment: RefCounted) -> Dictionary:
	var entries := []
	for slot in equipment.worn:
		var item_id: String = equipment.worn[slot]
		if not item_id.is_empty():
			var quantity: int = equipment.ammo_count if slot == "ammo" else 1
			entries.append({"item": item_id, "quantity": quantity, "worn_slot": slot})
	for slot in inventory.slots:
		if slot == null:
			continue
		if inventory.stacks(slot["item"]):
			entries.append({"item": slot["item"], "quantity": slot["quantity"]})
		else:
			for i in slot["quantity"]:
				entries.append({"item": slot["item"], "quantity": 1})
	# Stable order: value descending, then worn before carried, then id.
	entries.sort_custom(func(a, b):
		var va: int = ContentDB.item(a["item"])["value"]
		var vb: int = ContentDB.item(b["item"])["value"]
		if va != vb:
			return va > vb
		if a.has("worn_slot") != b.has("worn_slot"):
			return a.has("worn_slot")
		return a["item"] < b["item"])

	var result := {"kept_worn": [], "kept_inventory": [], "lost": []}
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var item := {"item": entry["item"], "quantity": entry["quantity"]}
		if i < KEPT_ON_DEATH:
			if entry.has("worn_slot"):
				result["kept_worn"].append(entry["worn_slot"])
			else:
				result["kept_inventory"].append(item)
		else:
			result["lost"].append(item)
	return result


static func reclaim_fee(items: Array) -> int:
	var total := 0
	for entry in items:
		total += ContentDB.item(entry["item"])["value"] * entry["quantity"]
	return ceili(total * RECLAIM_FEE_RATE)


## Merges entries for the same item, so graves and storage list each item
## once. Containers split unstackables back into slots when items return.
static func merge(items: Array) -> Array:
	var merged := []
	for entry in items:
		var existing: Variant = null
		for other in merged:
			if other["item"] == entry["item"]:
				existing = other
		if existing:
			existing["quantity"] += entry["quantity"]
		else:
			merged.append(entry.duplicate())
	return merged
