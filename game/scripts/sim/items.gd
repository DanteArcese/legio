extends RefCounted
## Inventory, equipment, bank, ground items, and shops.

const Combatant := preload("res://scripts/sim/combatant.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")
const Equipment := preload("res://scripts/sim/equipment.gd")

## Ground items disappear after this many ticks (2 minutes).
const GROUND_LIFETIME := 200
const PICKUP_RANGE := 2.0
const BANK_RANGE := 3.0
const SHOP_RANGE := 3.0
## Eating delays your next attack by this many ticks.
const EAT_DELAY := 3
## Drops this close to an existing pile join it.
const PILE_MERGE_RADIUS := 1.5

## Held weakly: the simulation owns this module, so a strong reference back
## would form a cycle that is never freed.
var sim: RefCounted:
	get:
		return _sim_ref.get_ref()
	set(value):
		_sim_ref = weakref(value)
var _sim_ref: WeakRef
## pile id -> {"id", "position", "items", "expires_at"}
var ground := {}
var banks: Array[Vector3] = []
## shop id -> shopkeeper position
var shopkeepers := {}
var _next_pile_id := 1


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


## Inventory, equipment, bank, and shop commands. slot is an inventory slot index.
func apply_command(player: Combatant, command: Dictionary, events: Array[Dictionary]) -> void:
	var slot_index: int = command.get("slot", -1)
	var slot: Variant = player.inventory.slots[slot_index] if slot_index >= 0 and slot_index < player.inventory.size else null
	match command["type"]:
		"equip":
			if slot == null or Equipment.slot_of(slot["item"]).is_empty():
				return
			var unmet := Equipment.unmet_requirement(slot["item"], player.skills)
			if not unmet.is_empty():
				sim.message(player, "You need %s to wear that." % unmet.capitalize(), events)
				return
			if Equipment.slot_of(slot["item"]) == "ammo":
				_equip_ammo(player, slot_index, events)
				return
			player.inventory.take_slot(slot_index)
			var previous: String = player.equipment.wear(slot["item"])
			if not previous.is_empty():
				player.inventory.slots[slot_index] = {"item": previous, "quantity": 1}
			equipment_changed(player, events)
		"unequip":
			var item_id: String = player.equipment.worn.get(command.get("equip_slot", ""), "")
			if item_id.is_empty():
				return
			var quantity: int = player.equipment.ammo_count if command["equip_slot"] == "ammo" else 1
			if player.inventory.space_for(item_id, quantity) < quantity:
				sim.message(player, "You don't have enough inventory space.", events)
				return
			player.equipment.take_off(command["equip_slot"])
			player.inventory.add(item_id, quantity)
			equipment_changed(player, events)
		"eat":
			if slot == null or not ContentDB.item(slot["item"]).has("heals"):
				return
			_remove_from_slot(player, slot_index, 1)
			var heal: int = ContentDB.item(slot["item"])["heals"]
			var healed := mini(heal, player.max_hp - player.hp)
			player.hp += healed
			player.next_attack_tick = maxi(player.next_attack_tick, sim.tick + EAT_DELAY)
			events.append({"type": "ate", "id": player.id, "item": slot["item"], "healed": healed, "tick": sim.tick})
			events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
		"drop":
			if slot == null:
				return
			player.inventory.take_slot(slot_index)
			add_ground_pile(player.position, [slot], events)
			events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
		"pickup":
			_pickup(player, command.get("pile", -1), command.get("item", ""), events)
		"buy":
			_buy(player, command.get("shop", ""), command.get("item", ""), events)
		"deposit", "deposit_all", "withdraw":
			if not _near_bank(player):
				sim.message(player, "You need to be at a bank.", events)
				return
			_bank_command(player, command, slot, events)


func equipment_changed(player: Combatant, events: Array) -> void:
	player.apply_equipment()
	events.append({"type": "equipment_changed", "id": player.id, "tick": sim.tick})
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})


func add_ground_pile(position: Vector3, items: Array, events: Array) -> void:
	var pile := {"id": _next_pile_id, "position": position, "items": items.duplicate(true), "expires_at": sim.tick + GROUND_LIFETIME}
	ground[_next_pile_id] = pile
	_next_pile_id += 1
	events.append({"type": "ground_add", "pile": pile["id"], "position": position, "items": pile["items"], "tick": sim.tick})


## Adds items to a pile within PILE_MERGE_RADIUS of position, or starts a new one.
func drop_near(position: Vector3, item_id: String, quantity: int, events: Array) -> void:
	for pile in ground.values():
		if sim.flat_distance(pile["position"], position) <= PILE_MERGE_RADIUS:
			var merged := false
			for entry in pile["items"]:
				if entry["item"] == item_id:
					entry["quantity"] += quantity
					merged = true
			if not merged:
				pile["items"].append({"item": item_id, "quantity": quantity})
			pile["expires_at"] = sim.tick + GROUND_LIFETIME
			events.append({"type": "ground_update", "pile": pile["id"], "items": pile["items"], "tick": sim.tick})
			return
	add_ground_pile(position, [{"item": item_id, "quantity": quantity}], events)


func expire_ground(events: Array[Dictionary]) -> void:
	for pile_id in ground.keys():
		if ground[pile_id]["expires_at"] <= sim.tick:
			ground.erase(pile_id)
			events.append({"type": "ground_remove", "pile": pile_id, "tick": sim.tick})


## Ammo is worn as a whole stack. Wearing more of the same kind adds to it;
## a different kind swaps places with the worn stack.
func _equip_ammo(player: Combatant, slot_index: int, events: Array[Dictionary]) -> void:
	var slot: Dictionary = player.inventory.take_slot(slot_index)
	var equipment: RefCounted = player.equipment
	if equipment.worn["ammo"] == slot["item"]:
		equipment.ammo_count += slot["quantity"]
	else:
		var previous: String = equipment.worn["ammo"]
		var previous_count: int = equipment.ammo_count
		equipment.worn["ammo"] = slot["item"]
		equipment.ammo_count = slot["quantity"]
		if not previous.is_empty():
			player.inventory.slots[slot_index] = {"item": previous, "quantity": previous_count}
	equipment_changed(player, events)


func _remove_from_slot(player: Combatant, index: int, quantity: int) -> void:
	var slot: Dictionary = player.inventory.slots[index]
	slot["quantity"] -= quantity
	if slot["quantity"] <= 0:
		player.inventory.slots[index] = null


func _bank_command(player: Combatant, command: Dictionary, slot: Variant, events: Array[Dictionary]) -> void:
	match command["type"]:
		"deposit":
			if slot == null:
				return
			var item_id: String = slot["item"]
			var quantity := mini(command.get("quantity", player.inventory.count(item_id)), player.inventory.count(item_id))
			var moved: int = player.bank.add(item_id, quantity)
			player.inventory.remove(item_id, moved)
		"deposit_all":
			for item_id in _distinct_items(player.inventory):
				player.inventory.remove(item_id, player.bank.add(item_id, player.inventory.count(item_id)))
		"withdraw":
			var item_id: String = command.get("item", "")
			var quantity := mini(command.get("quantity", 1), player.bank.count(item_id))
			var moved: int = player.inventory.add(item_id, quantity)
			player.bank.remove(item_id, moved)
			if moved < quantity:
				sim.message(player, "You don't have enough inventory space.", events)
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
	events.append({"type": "bank_changed", "id": player.id, "tick": sim.tick})


func _distinct_items(container: RefCounted) -> Array:
	var ids := []
	for slot in container.slots:
		if slot and not ids.has(slot["item"]):
			ids.append(slot["item"])
	return ids


func _near_bank(player: Combatant) -> bool:
	return banks.any(func(bank): return sim.flat_distance(bank, player.position) <= BANK_RANGE)


## Takes everything from a pile, or only one item id when item_id is set.
func _pickup(player: Combatant, pile_id: int, item_id: String, events: Array[Dictionary]) -> void:
	var pile: Dictionary = ground.get(pile_id, {})
	if pile.is_empty() or sim.flat_distance(pile["position"], player.position) > PICKUP_RANGE:
		return
	var remaining := []
	var took_any := false
	for entry in pile["items"]:
		if not item_id.is_empty() and entry["item"] != item_id:
			remaining.append(entry)
			continue
		var added: int = player.inventory.add(entry["item"], entry["quantity"])
		took_any = took_any or added > 0
		if added < entry["quantity"]:
			remaining.append({"item": entry["item"], "quantity": entry["quantity"] - added})
	if took_any:
		events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
	if remaining.is_empty():
		ground.erase(pile_id)
		events.append({"type": "ground_remove", "pile": pile_id, "tick": sim.tick})
	else:
		var stuck := remaining.any(func(entry): return item_id.is_empty() or entry["item"] == item_id)
		pile["items"] = remaining
		events.append({"type": "ground_update", "pile": pile_id, "items": remaining, "tick": sim.tick})
		if stuck:
			sim.message(player, "You don't have enough inventory space.", events)


## Buys from a shopkeeper with coins from the inventory.
func _buy(player: Combatant, shop_id: String, item_id: String, events: Array[Dictionary]) -> void:
	if not shopkeepers.has(shop_id) or sim.flat_distance(shopkeepers[shop_id], player.position) > SHOP_RANGE:
		return
	var shop := ContentDB.shop(shop_id)
	if shop.has("requires_quest") and not player.quests.get(shop["requires_quest"], {}).get("done", false):
		sim.message(player, "Only soldiers of the cohort may draw from these stores.", events)
		return
	var offers: Array = shop.get("offers", []).filter(func(o): return o["item"] == item_id)
	if offers.is_empty():
		return
	if offers[0].has("requires_quest") and not player.quests.get(offers[0]["requires_quest"], {}).get("done", false):
		sim.message(player, "The quartermaster keeps that for proven soldiers.", events)
		return
	var price: int = offers[0]["price"]
	var quantity: int = offers[0].get("quantity", 1)
	if player.inventory.count("coins") < price:
		sim.message(player, "You need %d denarii for that." % price, events)
		return
	if player.inventory.space_for(item_id, quantity) < quantity and player.inventory.count("coins") > price:
		sim.message(player, "You don't have enough inventory space.", events)
		return
	player.inventory.remove("coins", price)
	sim.give_item(player.id, item_id, quantity, "shop", events)
	var name: String = ContentDB.item(item_id)["name"].to_lower()
	sim.message(player, "You buy %s." % (("a " + name) if quantity == 1 else "%d %s" % [quantity, name]), events)
