extends RefCounted
## Rolls drop tables. Takes the simulation's RNG so drops stay deterministic.


## Returns an array of {"item": id, "quantity": n}, with guaranteed drops first.
static func roll(table: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in table.get("always", []):
		result.append({"item": entry["item"], "quantity": _quantity(entry, rng)})
	var entries: Array = table.get("table", [])
	var total_weight := 0
	for entry in entries:
		total_weight += entry["weight"]
	for i in table.get("rolls", 0):
		var pick := rng.randi_range(1, total_weight)
		for entry in entries:
			pick -= entry["weight"]
			if pick <= 0:
				if entry["item"] != null:
					result.append({"item": entry["item"], "quantity": _quantity(entry, rng)})
				break
	return result


static func _quantity(entry: Dictionary, rng: RandomNumberGenerator) -> int:
	var quantity: Variant = entry.get("quantity", 1)
	if quantity is Array:
		return rng.randi_range(quantity[0], quantity[1])
	return quantity
