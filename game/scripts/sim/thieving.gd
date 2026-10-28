extends RefCounted
## Thieving: stealing from market stalls, picking pockets, and cracking
## strongboxes. Stalls empty for a while after a theft, and a seen theft
## inside the walls brings the town watch. A failed pickpocket gets you
## stunned and roughed up. A strongbox takes a few ticks of work with a
## lockpick; a sprung trap hurts and may snap the pick, and a cracked box
## stays empty until it's refilled.

const Combatant := preload("res://scripts/sim/combatant.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")
const Pietas := preload("res://scripts/sim/pietas.gd")
const Drops := preload("res://scripts/sim/drops.gd")

const STALL_RANGE := 2.2
const MARK_RANGE := 2.0
## Ticks between attempts.
const ATTEMPT_TICKS := 2
## Pickpocket success: our own curve, better with level above the mark's.
const PICKPOCKET_BASE := 0.55
const PICKPOCKET_PER_LEVEL := 0.012
## Each level above a stall's makes being caught a little less likely.
const CAUGHT_PER_LEVEL := 0.008
const STRONGBOX_RANGE := 2.2
## Each level above a strongbox's makes its trap a little less likely.
const TRAP_PER_LEVEL := 0.01
## A sprung trap snaps the pick this often.
const PICK_BREAK_CHANCE := 0.5

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
## strongbox id -> {"id", "type", "position", "empty_until"}
var strongboxes := {}


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


func add_stall(id: int, stall_type: String, position: Vector3) -> void:
	stalls[id] = {"id": id, "type": stall_type, "position": position, "empty_until": -1}


func add_mark(id: int, mark_type: String, position: Vector3) -> void:
	marks[id] = {"id": id, "type": mark_type, "position": position}


func add_strongbox(id: int, box_type: String, position: Vector3) -> void:
	strongboxes[id] = {"id": id, "type": box_type, "position": position, "empty_until": -1}


static func strongbox_data(box_type: String) -> Dictionary:
	return ContentDB.data()["thieving"]["strongboxes"][box_type]


static func trap_chance(level: int, box: Dictionary) -> float:
	return clampf(box["trap_chance"] - TRAP_PER_LEVEL * (level - box["level"]), 0.05, 0.95)


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


## Starts working the lock; the attempt resolves after the box's crack_ticks.
func crack(player: Combatant, box_id: int, events: Array) -> void:
	var box: Dictionary = strongboxes.get(box_id, {})
	if box.is_empty() or sim.flat_distance(box["position"], player.position) > STRONGBOX_RANGE or not _ready(player):
		return
	var data := strongbox_data(box["type"])
	if player.skills.level("thieving") < data["level"]:
		sim.message(player, "You need Thieving %d to crack the %s." % [data["level"], data["name"].to_lower()], events)
		return
	if player.inventory.count("lockpick") == 0:
		sim.message(player, "You need a lockpick.", events)
		return
	if box["empty_until"] != -1:
		sim.message(player, "It's already been emptied. Someone will refill it, in time.", events)
		return
	player.target_id = -1
	player.skill_action = {"type": "crack", "box": box_id, "done": sim.tick + data["crack_ticks"]}
	events.append({"type": "skill_started", "id": player.id, "action": "crack", "tick": sim.tick})
	sim.message(player, "You set to work on the lock...", events)


func process(events: Array, players: Array = []) -> void:
	for stall in stalls.values():
		if stall["empty_until"] != -1 and stall["empty_until"] <= sim.tick:
			stall["empty_until"] = -1
			events.append({"type": "stall_restocked", "stall": stall["id"], "tick": sim.tick})
	for box in strongboxes.values():
		if box["empty_until"] != -1 and box["empty_until"] <= sim.tick:
			box["empty_until"] = -1
			events.append({"type": "strongbox_refilled", "strongbox": box["id"], "tick": sim.tick})
	for player: Combatant in players:
		var action: Dictionary = player.skill_action
		if action.get("type") == "crack" and sim.tick >= action["done"]:
			player.skill_action = {}
			_finish_crack(player, action["box"], events)
			events.append({"type": "skill_stopped", "id": player.id, "tick": sim.tick})


func _finish_crack(player: Combatant, box_id: int, events: Array) -> void:
	var box: Dictionary = strongboxes[box_id]
	var data := strongbox_data(box["type"])
	if sim.flat_distance(box["position"], player.position) > STRONGBOX_RANGE or box["empty_until"] != -1 or player.inventory.count("lockpick") == 0:
		return
	player.thieving_ready_at = sim.tick + ATTEMPT_TICKS
	if sim.rng.randf() < trap_chance(player.skills.level("thieving"), data):
		var damage := mini(sim.rng.randi_range(data["damage"][0], data["damage"][1]), player.hp - 1)
		player.hp -= damage
		events.append({"type": "hit", "attacker": -1, "target": player.id, "damage": damage, "ranged": false, "kind": "melee", "tick": sim.tick})
		if sim.rng.randf() < PICK_BREAK_CHANCE:
			player.inventory.remove("lockpick", 1)
			events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
			sim.message(player, "A needle springs from the lock! Your pick snaps.", events)
		else:
			sim.message(player, "A needle springs from the lock and jabs your hand.", events)
		return
	var loot := Drops.roll(ContentDB.drop_table(data["drop_table"]), sim.rng)
	for entry in loot:
		sim.give_item(player.id, entry["item"], entry["quantity"], "thieving", events)
	sim.award_xp(player, "thieving", data["xp"], events)
	box["empty_until"] = sim.tick + data["relock_ticks"]
	events.append({"type": "strongbox_emptied", "strongbox": box_id, "tick": sim.tick})
	var names := loot.map(func(e): return "%d %s" % [e["quantity"], ContentDB.item(e["item"])["name"].to_lower()] if e["quantity"] > 1 else ContentDB.item(e["item"])["name"].to_lower())
	sim.message(player, "The lock gives. Inside: %s." % ", ".join(names), events)


func _ready(player: Combatant) -> bool:
	return sim.tick >= player.thieving_ready_at and not is_stunned(player, sim.tick)
