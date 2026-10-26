extends RefCounted
## Mercatura: trade contracts. A trade board offers cargoes wanted somewhere
## else; take one, source the goods yourself, and deliver them to the
## shopkeeper who wants them for coins and Mercatura XP. One at a time.

const Combatant := preload("res://scripts/sim/combatant.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const BOARD_RANGE := 3.0
const DELIVER_RANGE := 3.0

## Held weakly: the simulation owns this module, so a strong reference back
## would form a cycle that is never freed.
var sim: RefCounted:
	get:
		return _sim_ref.get_ref()
	set(value):
		_sim_ref = weakref(value)
var _sim_ref: WeakRef
## board id -> position
var boards := {}


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


func add_board(board_id: String, position: Vector3) -> void:
	boards[board_id] = position


## Contracts this board offers at this Mercatura level, in content order.
static func contracts_on(board_id: String, level: int) -> Array:
	var out := []
	var contracts: Dictionary = ContentDB.data()["mercatura"]["contracts"]
	for contract_id in contracts:
		if contracts[contract_id]["board"] == board_id and contracts[contract_id]["level"] <= level:
			out.append(contract_id)
	return out


func take(player: Combatant, board_id: String, contract_id: String, events: Array) -> void:
	if not boards.has(board_id) or sim.flat_distance(boards[board_id], player.position) > BOARD_RANGE:
		return
	var contract := ContentDB.contract(contract_id)
	if contract.is_empty() or contract["board"] != board_id:
		return
	if not player.trade_contract.is_empty():
		sim.message(player, "Finish or abandon your current contract first.", events)
		return
	if player.skills.level("mercatura") < contract["level"]:
		sim.message(player, "You need Mercatura %d for that contract." % contract["level"], events)
		return
	player.trade_contract = {"id": contract_id}
	events.append({"type": "contract_taken", "id": player.id, "contract": contract_id, "tick": sim.tick})
	sim.message(player, "Contract: %d %s for the %s." % [contract["quantity"], ContentDB.item(contract["item"])["name"].to_lower(),
		ContentDB.shop(contract["to"])["name"].to_lower()], events)


func abandon(player: Combatant, events: Array) -> void:
	if player.trade_contract.is_empty():
		return
	player.trade_contract = {}
	events.append({"type": "contract_abandoned", "id": player.id, "tick": sim.tick})
	sim.message(player, "You tear up the contract.", events)


## Hands the cargo to the shopkeeper the contract is for.
func deliver(player: Combatant, shop_id: String, events: Array) -> void:
	if player.trade_contract.is_empty():
		return
	var contract := ContentDB.contract(player.trade_contract["id"])
	if contract["to"] != shop_id:
		return
	var at: Variant = sim.items.shopkeepers.get(shop_id)
	if at == null or sim.flat_distance(at, player.position) > DELIVER_RANGE:
		return
	if player.inventory.count(contract["item"]) < contract["quantity"]:
		sim.message(player, "You need %d %s for this contract." % [contract["quantity"], ContentDB.item(contract["item"])["name"].to_lower()], events)
		return
	player.inventory.remove(contract["item"], contract["quantity"])
	player.trade_contract = {}
	player.contracts_done += 1
	sim.give_item(player.id, "coins", contract["coins"], "contract", events)
	sim.award_xp(player, "mercatura", contract["xp"], events)
	events.append({"type": "contract_complete", "id": player.id, "contract": contract["name"], "tick": sim.tick})
	sim.message(player, "Contract complete: %s. You're paid %d denarii." % [contract["name"], contract["coins"]], events)
