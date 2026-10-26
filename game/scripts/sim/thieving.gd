extends RefCounted
## Thieving: stealing from market stalls and picking pockets. Stalls empty
## for a while after a theft, and a seen theft inside the walls brings the
## town watch. A failed pickpocket gets you stunned and roughed up.

const Combatant := preload("res://scripts/sim/combatant.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")
const Pietas := preload("res://scripts/sim/pietas.gd")

const STALL_RANGE := 2.2
const MARK_RANGE := 2.0
## Ticks between attempts.
const ATTEMPT_TICKS := 2
## Pickpocket success: our own curve, better with level above the mark's.
const PICKPOCKET_BASE := 0.55
const PICKPOCKET_PER_LEVEL := 0.012
## Each level above a stall's makes being caught a little less likely.
const CAUGHT_PER_LEVEL := 0.008

## Held weakly: the simulation owns this module, so a strong reference back
## would form a cycle that is never freed.
var sim: RefCounted:
	get:
		return _sim_ref.get_ref()
	set(value):
		_sim_ref = weakref(value)
var _sim_ref: WeakRef
## stall id -> {"id", "type", "position", "empty_until"}
var stalls := {}
## mark id -> {"id", "type", "position"}
var marks := {}


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


func add_stall(id: int, stall_type: String, position: Vector3) -> void:
	stalls[id] = {"id": id, "type": stall_type, "position": position, "empty_until": -1}


func add_mark(id: int, mark_type: String, position: Vector3) -> void:
	marks[id] = {"id": id, "type": mark_type, "position": position}


static func pickpocket_chance(level: int, mark: Dictionary) -> float:
	return clampf(PICKPOCKET_BASE + PICKPOCKET_PER_LEVEL * (level - mark["level"]), 0.05, 0.95)


static func caught_chance(level: int, stall: Dictionary) -> float:
	return clampf(stall["caught_chance"] - CAUGHT_PER_LEVEL * (level - stall["level"]), 0.02, 0.95)


static func is_stunned(player: Combatant, tick: int) -> bool:
	return player.stunned_until > tick


func steal(player: Combatant, stall_id: int, events: Array) -> void:
	var stall: Dictionary = stalls.get(stall_id, {})
	if stall.is_empty() or sim.flat_distance(stall["position"], player.position) > STALL_RANGE or not _ready(player):
		return
	var data := ContentDB.stall(stall["type"])
	var level: int = player.skills.level("thieving")
	if level < data["level"]:
		sim.message(player, "You need Thieving %d to steal from the %s." % [data["level"], data["name"].to_lower()], events)
		return
	if stall["empty_until"] != -1:
		sim.message(player, "There's nothing left to take. Come back later.", events)
		return
	player.target_id = -1
	player.thieving_ready_at = sim.tick + ATTEMPT_TICKS
	if sim.rng.randf() < caught_chance(level, data):
		sim.message(player, "\"Thief!\" The stallholder grabs your wrist.", events)
		events.append({"type": "caught", "id": player.id, "tick": sim.tick})
		if Pietas.in_town(player.position):
			sim.pietas.town_watch(player, events, "A vigil hauls you off the stall: \"Hands to yourself, or it's a fine next time.\"", "theft")
		return
	var loot: Dictionary = data["loot"]
	sim.give_item(player.id, loot["item"], loot["quantity"], "thieving", events)
	sim.award_xp(player, "thieving", data["xp"], events)
	stall["empty_until"] = sim.tick + data["restock_ticks"]
	events.append({"type": "stall_emptied", "stall": stall_id, "tick": sim.tick})
	sim.message(player, "You steal %s from the %s." % [ContentDB.item(loot["item"])["name"].to_lower(), data["name"].to_lower()], events)


func pickpocket(player: Combatant, mark_id: int, events: Array) -> void:
	var mark: Dictionary = marks.get(mark_id, {})
	if mark.is_empty() or sim.flat_distance(mark["position"], player.position) > MARK_RANGE or not _ready(player):
		return
	var data := ContentDB.mark(mark["type"])
	var level: int = player.skills.level("thieving")
	if level < data["level"]:
		sim.message(player, "You need Thieving %d to pick the %s's pocket." % [data["level"], data["name"].to_lower()], events)
		return
	player.target_id = -1
	player.thieving_ready_at = sim.tick + ATTEMPT_TICKS
	if sim.rng.randf() < pickpocket_chance(level, data):
		var coins: int = sim.rng.randi_range(data["coins"][0], data["coins"][1])
		sim.give_item(player.id, "coins", coins, "thieving", events)
		sim.award_xp(player, "thieving", data["xp"], events)
		events.append({"type": "pickpocketed", "id": player.id, "mark": mark_id, "coins": coins, "tick": sim.tick})
		sim.message(player, "You pick the %s's pocket: %d denarii." % [data["name"].to_lower(), coins], events)
		return
	# Caught: a cuff round the ear that can hurt, but never kills.
	var damage := mini(sim.rng.randi_range(data["damage"][0], data["damage"][1]), player.hp - 1)
	player.hp -= damage
	player.stunned_until = sim.tick + data["stun_ticks"]
	player.thieving_ready_at = player.stunned_until
	events.append({"type": "hit", "attacker": -1, "target": player.id, "damage": damage, "ranged": false, "kind": "melee", "tick": sim.tick})
	events.append({"type": "stunned", "id": player.id, "until": player.stunned_until, "tick": sim.tick})
	sim.message(player, "The %s catches your hand and cuffs you. You're stunned!" % data["name"].to_lower(), events)


func process(events: Array) -> void:
	for stall in stalls.values():
		if stall["empty_until"] != -1 and stall["empty_until"] <= sim.tick:
			stall["empty_until"] = -1
			events.append({"type": "stall_restocked", "stall": stall["id"], "tick": sim.tick})


func _ready(player: Combatant) -> bool:
	return sim.tick >= player.thieving_ready_at and not is_stunned(player, sim.tick)
