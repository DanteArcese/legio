extends RefCounted
## What happens to a player's items on death: the grave, the libitinarii
## who collect it, and paying them to get things back.

const Combatant := preload("res://scripts/sim/combatant.gd")
const Equipment := preload("res://scripts/sim/equipment.gd")
const DeathRules := preload("res://scripts/sim/death_rules.gd")

const GRAVE_RANGE := 2.0
const LIBITINARIUS_RANGE := 3.0
## Graves last 15 minutes before the libitinarii collect the items.
const GRAVE_LIFETIME := 1500
## Beyond the Limes there are no graves: what you lose lies on the ground
## for 3 minutes, then it is gone for good.
const DANGER_PILE_LIFETIME := 300

## Held weakly: the simulation owns this module, so a strong reference back
## would form a cycle that is never freed.
var sim: RefCounted:
	get:
		return _sim_ref.get_ref()
	set(value):
		_sim_ref = weakref(value)
var _sim_ref: WeakRef
var libitinarii: Array[Vector3] = []
## player id -> {"id", "position", "items", "expires_at"}. One grave per player.
var _graves := {}
var _next_grave_id := 1


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


func grave_of(player_id: int) -> Dictionary:
	return _graves.get(player_id, {})


## Recreates a grave from a save, with the time it had left.
func restore(player_id: int, position: Vector3, items: Array, ticks_left: int) -> void:
	_graves[player_id] = {"id": _next_grave_id, "position": position, "items": items, "expires_at": sim.tick + maxi(ticks_left, 1)}
	_next_grave_id += 1


## Keep the most valuable items; the rest go to a grave at the death spot.
## A previous grave still standing goes straight to the libitinarii.
## Beyond the Limes the rest drop on the ground instead, past recovering
## once they vanish, and an earlier grave is left alone.
func on_player_death(player: Combatant, events: Array[Dictionary]) -> void:
	var tick: int = sim.tick
	var split := DeathRules.split(player.inventory, player.equipment)
	for slot in Equipment.SLOTS:
		if not split["kept_worn"].has(slot):
			player.equipment.take_off(slot)
	player.inventory.slots.fill(null)
	for entry in split["kept_inventory"]:
		player.inventory.add(entry["item"], entry["quantity"])
	player.apply_equipment()
	events.append({"type": "inventory_changed", "id": player.id, "tick": tick})
	events.append({"type": "equipment_changed", "id": player.id, "tick": tick})
	var lost: Array = DeathRules.merge(split["lost"])
	if sim.in_danger_zone(player.position):
		if not lost.is_empty():
			sim.items.add_ground_pile(player.position, lost, events, DANGER_PILE_LIFETIME)
			sim.message(player, "Beyond the Limes there are no graves. You keep your %d most valuable items; the rest lie where you fell for %d minutes." % [
				DeathRules.KEPT_ON_DEATH, roundi(DANGER_PILE_LIFETIME * 0.6 / 60.0)], events)
		return
	if _graves.has(player.id):
		_send_to_libitinarii(player.id, events)
	if lost.is_empty():
		return
	var grave := {"id": _next_grave_id, "position": player.position, "items": lost, "expires_at": tick + GRAVE_LIFETIME}
	_next_grave_id += 1
	_graves[player.id] = grave
	sim.message(player, "You keep your %d most valuable items. The rest lie in your grave for %d minutes." % [
		DeathRules.KEPT_ON_DEATH, roundi(GRAVE_LIFETIME * 0.6 / 60.0)], events)
	events.append({"type": "grave_add", "id": player.id, "grave": grave["id"], "position": grave["position"],
		"items": lost, "expires_at": grave["expires_at"], "tick": tick})


func loot(player: Combatant, events: Array[Dictionary]) -> void:
	var grave: Dictionary = _graves.get(player.id, {})
	if grave.is_empty() or sim.flat_distance(grave["position"], player.position) > GRAVE_RANGE:
		return
	var remaining := []
	for entry in grave["items"]:
		var added: int = player.inventory.add(entry["item"], entry["quantity"])
		if added < entry["quantity"]:
			remaining.append({"item": entry["item"], "quantity": entry["quantity"] - added})
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
	if remaining.is_empty():
		_graves.erase(player.id)
		events.append({"type": "grave_remove", "id": player.id, "grave": grave["id"], "tick": sim.tick})
		sim.message(player, "You recover your belongings.", events)
	else:
		grave["items"] = remaining
		sim.message(player, "You don't have enough inventory space.", events)


func expire(events: Array[Dictionary]) -> void:
	for player_id in _graves.keys():
		if _graves[player_id]["expires_at"] <= sim.tick:
			_send_to_libitinarii(player_id, events)


## Pay the libitinarii to return held items to the bank. Coins come from
## the inventory first, then the bank.
func reclaim(player: Combatant, events: Array[Dictionary]) -> void:
	if not libitinarii.any(func(at): return sim.flat_distance(at, player.position) <= LIBITINARIUS_RANGE):
		return
	var items: Array = sim.reclaimable.get(player.id, [])
	if items.is_empty():
		sim.message(player, "The libitinarius has nothing of yours.", events)
		return
	var fee := DeathRules.reclaim_fee(items)
	var coins: int = player.inventory.count("coins") + player.bank.count("coins")
	if coins < fee:
		sim.message(player, "The libitinarius wants %d denarii to return your belongings." % fee, events)
		return
	var from_inventory: int = player.inventory.remove("coins", fee)
	player.bank.remove("coins", fee - from_inventory)
	for entry in items:
		player.bank.add(entry["item"], entry["quantity"])
	sim.reclaimable.erase(player.id)
	sim.message(player, "You pay %d denarii. Your belongings are waiting in your bank." % fee, events)
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
	events.append({"type": "bank_changed", "id": player.id, "tick": sim.tick})


func _send_to_libitinarii(player_id: int, events: Array[Dictionary]) -> void:
	var grave: Dictionary = _graves[player_id]
	_graves.erase(player_id)
	sim.reclaimable[player_id] = DeathRules.merge(sim.reclaimable.get(player_id, []) + grave["items"])
	events.append({"type": "grave_remove", "id": player_id, "grave": grave["id"], "tick": sim.tick})
	events.append({"type": "message", "id": player_id,
		"text": "The libitinarii have collected your belongings from your grave.", "tick": sim.tick})
