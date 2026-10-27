extends RefCounted
## Arena contracts: the lanista at Portus Salis buys beasts for the games in
## Rome. Take a contract, beat the beast down below a quarter of its health,
## and throw a weighted net over it: it's taken alive (no drops) for Hunter
## XP, and the lanista pays when the contract is done. One at a time.

const Combatant := preload("res://scripts/sim/combatant.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const LANISTA_RANGE := 3.0
const CAPTURE_RANGE := 3.0

## Held weakly: the simulation owns this module, so a strong reference back
## would form a cycle that is never freed.
var sim: RefCounted:
	get:
		return _sim_ref.get_ref()
	set(value):
		_sim_ref = weakref(value)
var _sim_ref: WeakRef
var lanista_position = null


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


func set_lanista(position: Vector3) -> void:
	lanista_position = position


static func data() -> Dictionary:
	return ContentDB.data()["arena"]


## Contract ids open at this Hunter level, in content order.
static func contracts_for(hunter_level: int) -> Array:
	var out := []
	for contract_id in data()["contracts"]:
		if data()["contracts"][contract_id]["hunter"] <= hunter_level:
			out.append(contract_id)
	return out


func _near_lanista(player: Combatant) -> bool:
	return lanista_position != null and sim.flat_distance(lanista_position, player.position) <= LANISTA_RANGE


func take(player: Combatant, contract_id: String, events: Array) -> void:
	var contract: Dictionary = data()["contracts"].get(contract_id, {})
	if contract.is_empty() or not _near_lanista(player) or not player.arena_contract.is_empty():
		return
	if player.skills.level("hunter") < contract["hunter"]:
		sim.message(player, "You need Hunter %d to take that contract." % contract["hunter"], events)
		return
	player.arena_contract = {"id": contract_id, "remaining": contract["count"]}
	sim.message(player, "Bring them in alive: weaken a %s below a quarter of its health, then throw a net." % ContentDB.monster(contract["monster"])["name"].to_lower(), events)
	events.append({"type": "arena_contract", "id": player.id, "contract": contract_id, "tick": sim.tick})


func abandon(player: Combatant, events: Array) -> void:
	if player.arena_contract.is_empty():
		return
	player.arena_contract = {}
	sim.message(player, "You give up the contract.", events)


## Throws a net over a weakened beast. Needs a net, the contract's beast,
## and the beast below the capture threshold.
func capture(player: Combatant, target_id: int, events: Array) -> void:
	var target: Combatant = sim.get_combatant(target_id)
	if target == null or not target.is_alive() or player.arena_contract.is_empty():
		return
	var contract: Dictionary = data()["contracts"][player.arena_contract["id"]]
	if target.monster_id != contract["monster"]:
		sim.message(player, "The lanista doesn't want one of those.", events)
		return
	if sim.flat_distance(player.position, target.position) > CAPTURE_RANGE:
		return
	if player.inventory.count(data()["net"]) == 0:
		sim.message(player, "You need a weighted net.", events)
		return
	if target.hp > target.max_hp * float(data()["capture_below"]):
		sim.message(player, "It's too lively to net. Weaken it first.", events)
		return
	player.inventory.remove(data()["net"], 1)
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
	sim.capture(target, events)
	sim.award_xp(player, "hunter", contract["xp"], events)
	player.arena_contract["remaining"] -= 1
	events.append({"type": "captured", "id": target.id, "by": player.id, "tick": sim.tick})
	if player.arena_contract["remaining"] > 0:
		sim.message(player, "Netted! %d more to go." % player.arena_contract["remaining"], events)
	else:
		sim.message(player, "Netted! That's the lot. Back to the lanista at Portus Salis.", events)


## The lanista pays for a finished contract.
func hand_in(player: Combatant, events: Array) -> void:
	if player.arena_contract.is_empty() or player.arena_contract["remaining"] > 0 or not _near_lanista(player):
		return
	var contract: Dictionary = data()["contracts"][player.arena_contract["id"]]
	player.arena_contract = {}
	player.arena_contracts_done += 1
	sim.give_item(player.id, "coins", contract["coins"], "arena", events)
	sim.message(player, "The lanista counts out %d denarii. \"They'll love these in Rome.\"" % contract["coins"], events)
	events.append({"type": "arena_complete", "id": player.id, "coins": contract["coins"], "tick": sim.tick})
