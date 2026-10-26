extends RefCounted
## Hunter: box traps set at burrows and dens. A set trap springs by chance
## every few ticks; checking a sprung trap gives the catch and the trap back.

const Combatant := preload("res://scripts/sim/combatant.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const TRAP_RANGE := 2.2
## A set trap rolls for a catch this often.
const ROLL_TICKS := 4
## Each level above a spot's adds this to its catch chance.
const CHANCE_PER_LEVEL := 0.01

## Held weakly: the simulation owns this module, so a strong reference back
## would form a cycle that is never freed.
var sim: RefCounted:
	get:
		return _sim_ref.get_ref()
	set(value):
		_sim_ref = weakref(value)
var _sim_ref: WeakRef
## spot id -> {"id", "type", "position", "trap": {} or {"owner", "state": "set" | "caught", "next_roll"}}
var spots := {}


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


func add_spot(id: int, spot_type: String, position: Vector3) -> void:
	spots[id] = {"id": id, "type": spot_type, "position": position, "trap": {}}


static func catch_chance(level: int, spot: Dictionary) -> float:
	return clampf(spot["catch_chance"] + CHANCE_PER_LEVEL * (level - spot["level"]), 0.05, 0.9)


## How many of this player's traps are out (saves hand them back).
func traps_out(player_id: int) -> int:
	return spots.values().filter(func(spot): return spot["trap"].get("owner", -1) == player_id).size()


## Sets a trap at a free spot, or checks the player's own trap there.
func use_spot(player: Combatant, spot_id: int, events: Array) -> void:
	var spot: Dictionary = spots.get(spot_id, {})
	if spot.is_empty() or sim.flat_distance(spot["position"], player.position) > TRAP_RANGE:
		return
	var data := ContentDB.hunt_spot(spot["type"])
	var trap: Dictionary = spot["trap"]
	if trap.is_empty():
		_set_trap(player, spot, data, events)
	elif trap["owner"] != player.id:
		sim.message(player, "Someone else's trap is set here.", events)
	elif trap["state"] == "set":
		sim.message(player, "Nothing yet. Give it time.", events)
	else:
		_collect(player, spot, data, events)


func process(events: Array) -> void:
	for spot in spots.values():
		var trap: Dictionary = spot["trap"]
		if trap.is_empty() or trap["state"] != "set" or sim.tick < trap["next_roll"]:
			continue
		trap["next_roll"] = sim.tick + ROLL_TICKS
		var owner: Combatant = sim.get_combatant(trap["owner"])
		var level: int = owner.skills.level("hunter") if owner else 1
		if sim.rng.randf() < catch_chance(level, ContentDB.hunt_spot(spot["type"])):
			trap["state"] = "caught"
			events.append({"type": "trap_caught", "spot": spot["id"], "id": trap["owner"], "tick": sim.tick})


func _set_trap(player: Combatant, spot: Dictionary, data: Dictionary, events: Array) -> void:
	if player.skills.level("hunter") < data["level"]:
		sim.message(player, "You need Hunter %d to trap here." % data["level"], events)
		return
	if player.inventory.count("box_trap") == 0:
		sim.message(player, "You need a box trap.", events)
		return
	player.inventory.remove("box_trap", 1)
	spot["trap"] = {"owner": player.id, "state": "set", "next_roll": sim.tick + ROLL_TICKS}
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
	events.append({"type": "trap_set", "spot": spot["id"], "id": player.id, "tick": sim.tick})
	sim.message(player, "You set a box trap at the %s." % data["name"].to_lower(), events)


func _collect(player: Combatant, spot: Dictionary, data: Dictionary, events: Array) -> void:
	# Room for the catch and the trap coming back.
	var needed: int = data["loot"].size() + 1
	if player.inventory.free_slots() < needed:
		sim.message(player, "You don't have enough inventory space.", events)
		return
	spot["trap"] = {}
	for entry in data["loot"]:
		sim.give_item(player.id, entry["item"], entry["quantity"], "skilling", events)
	sim.give_item(player.id, "box_trap", 1, "skilling", events)
	sim.award_xp(player, "hunter", data["xp"], events)
	events.append({"type": "trap_cleared", "spot": spot["id"], "id": player.id, "tick": sim.tick})
