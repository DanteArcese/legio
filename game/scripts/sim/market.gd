extends RefCounted
## The forum market in Rome: buy or sell anything tradeable through a
## broker. In single-player the other side is the city's traders, who keep a
## price for each item as a multiple of its value. Every unit sold pushes it
## down and every unit bought pushes it up, within bounds; every minute each
## price drifts part of the way back to the item's value. Buying costs a
## little over the market price and selling fetches a little under it.
## Solitarius characters can't trade here.

const Combatant := preload("res://scripts/sim/combatant.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

## How far one unit moves the price (multiplicatively).
const IMPACT := 0.03
const LOWEST := 0.3
const HIGHEST := 3.0
## Every DRIFT_TICKS, this share of the gap to the item's value closes.
const DRIFT_TICKS := 100
const DRIFT := 0.1
## The broker's cut either way.
const SPREAD := 0.1
const BROKER_RANGE := 3.0
## At most this many units in one order.
const MAX_ORDER := 1000

## Held weakly: the simulation owns this module, so a strong reference back
## would form a cycle that is never freed.
var sim: RefCounted:
	get:
		return _sim_ref.get_ref()
	set(value):
		_sim_ref = weakref(value)
var _sim_ref: WeakRef
## item id -> price as a multiple of value (absent means 1.0).
var prices := {}
var brokers: Array[Vector3] = []


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


func add_broker(position: Vector3) -> void:
	brokers.append(position)


## Whether the market deals in an item: anything with a value that isn't a
## quest item, a pet, or money.
static func tradeable(item_id: String) -> bool:
	var item := ContentDB.item(item_id)
	return not item.is_empty() and item_id != "coins" and int(item.get("value", 0)) > 0 \
		and not item.get("quest_item", false) and not item.has("pet")


func multiple(item_id: String) -> float:
	return prices.get(item_id, 1.0)


## What one unit trades at now, before the broker's cut.
func price(item_id: String) -> int:
	return maxi(1, roundi(int(ContentDB.item(item_id)["value"]) * multiple(item_id)))


## The cost of buying this many now, each unit raising the price for the next.
func buy_cost(item_id: String, quantity: int) -> int:
	var total := 0
	var m := multiple(item_id)
	var value := int(ContentDB.item(item_id)["value"])
	for i in quantity:
		total += maxi(1, ceili(value * m * (1.0 + SPREAD)))
		m = minf(m * (1.0 + IMPACT), HIGHEST)
	return total


## What selling this many fetches now, each unit lowering the price for the next.
func sell_return(item_id: String, quantity: int) -> int:
	var total := 0
	var m := multiple(item_id)
	var value := int(ContentDB.item(item_id)["value"])
	for i in quantity:
		total += maxi(1, floori(value * m * (1.0 - SPREAD)))
		m = maxf(m * (1.0 - IMPACT), LOWEST)
	return total


func buy(player: Combatant, item_id: String, quantity: int, events: Array) -> void:
	if not _ready_to_trade(player, item_id, events):
		return
	quantity = clampi(quantity, 1, MAX_ORDER)
	var room: int = player.inventory.space_for(item_id, quantity)
	if room <= 0:
		sim.message(player, "You don't have room for that.", events)
		return
	quantity = mini(quantity, room)
	var cost := buy_cost(item_id, quantity)
	if player.inventory.count("coins") < cost:
		sim.message(player, "That costs %d denarii at today's prices." % cost, events)
		return
	player.inventory.remove("coins", cost)
	sim.give_item(player.id, item_id, quantity, "market", events)
	prices[item_id] = minf(multiple(item_id) * pow(1.0 + IMPACT, quantity), HIGHEST)
	sim.message(player, "You buy %d %s for %d denarii." % [quantity, ContentDB.item(item_id)["name"].to_lower(), cost], events)
	events.append({"type": "market_trade", "id": player.id, "item": item_id, "quantity": quantity, "coins": -cost, "tick": sim.tick})


## Sells this many from the pack (all of them if quantity is 0).
func sell(player: Combatant, item_id: String, quantity: int, events: Array) -> void:
	if not _ready_to_trade(player, item_id, events):
		return
	var have: int = player.inventory.count(item_id)
	quantity = have if quantity <= 0 else mini(quantity, have)
	if quantity <= 0:
		return
	var fetched := sell_return(item_id, quantity)
	player.inventory.remove(item_id, quantity)
	sim.give_item(player.id, "coins", fetched, "shop", events)
	prices[item_id] = maxf(multiple(item_id) * pow(1.0 - IMPACT, quantity), LOWEST)
	sim.message(player, "You sell %d %s for %d denarii." % [quantity, ContentDB.item(item_id)["name"].to_lower(), fetched], events)
	events.append({"type": "market_trade", "id": player.id, "item": item_id, "quantity": -quantity, "coins": fetched, "tick": sim.tick})
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})


## Prices drift back toward value; those that are back are forgotten.
func process() -> void:
	if sim.tick % DRIFT_TICKS != 0:
		return
	for item_id in prices.keys():
		var m: float = prices[item_id]
		m += (1.0 - m) * DRIFT
		if absf(m - 1.0) < 0.01:
			prices.erase(item_id)
		else:
			prices[item_id] = m


func _ready_to_trade(player: Combatant, item_id: String, events: Array) -> bool:
	if not brokers.any(func(at): return sim.flat_distance(at, player.position) <= BROKER_RANGE):
		return false
	if player.is_solitarius():
		sim.message(player, "As a Solitarius, you stand alone. The market isn't for you.", events)
		return false
	if not tradeable(item_id):
		sim.message(player, "The market doesn't deal in that.", events)
		return false
	return true
