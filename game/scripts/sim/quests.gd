extends RefCounted
## Quests: talking to quest NPCs, step progress from attacks, kills,
## deliveries, and reaching places, and rewards. Each player's state lives in combatant.quests:
## quest id -> {"step": index of the current step, "progress": count toward it,
## "done": finished}. Quests not yet started have no entry.

const Combatant := preload("res://scripts/sim/combatant.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const TALK_RANGE := 3.0

## Held weakly: the simulation owns this module, so a strong reference back
## would form a cycle that is never freed.
var sim: RefCounted:
	get:
		return _sim_ref.get_ref()
	set(value):
		_sim_ref = weakref(value)
var _sim_ref: WeakRef
## npc id -> position
var npcs := {}


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


func add_npc(npc_id: String, position: Vector3) -> void:
	npcs[npc_id] = position


static func is_done(player: Combatant, quest_id: String) -> bool:
	return player.quests.get(quest_id, {}).get("done", false)


## "not_started", "in_progress", or "done".
static func status(player: Combatant, quest_id: String) -> String:
	if not player.quests.has(quest_id):
		return "not_started"
	return "done" if is_done(player, quest_id) else "in_progress"


## The current step's content, or {} when not in progress.
static func current_step(player: Combatant, quest_id: String) -> Dictionary:
	var state: Dictionary = player.quests.get(quest_id, {})
	if state.is_empty() or state.get("done", false):
		return {}
	return ContentDB.quest(quest_id)["steps"][state["step"]]


## Why the player can't start this quest yet, or "".
static func unmet_requirement(player: Combatant, quest_id: String) -> String:
	var requirements: Dictionary = ContentDB.quest(quest_id).get("requirements", {})
	for skill in requirements.get("skills", {}):
		if player.skills.level(skill) < requirements["skills"][skill]:
			return "%s %d" % [skill.capitalize(), requirements["skills"][skill]]
	for needed in requirements.get("quests", []):
		if not is_done(player, needed):
			return "the quest %s" % ContentDB.quest(needed)["name"]
	return ""


## The highest rank earned from quests, or "".
static func rank(player: Combatant) -> String:
	var best := ""
	for quest_id in ContentDB.quest_ids():
		if is_done(player, quest_id):
			best = ContentDB.quest(quest_id)["rewards"].get("rank", best)
	return best


## Talking to an NPC hands in a finished step, offers a quest, or reminds
## the player what to do next. Always answers with a dialogue event.
func talk(player: Combatant, npc_id: String, events: Array) -> void:
	if not npcs.has(npc_id) or sim.flat_distance(npcs[npc_id], player.position) > TALK_RANGE:
		return
	# A quest waiting to be handed in to this NPC comes first, then deliveries.
	for quest_id in ContentDB.quest_ids():
		var step := current_step(player, quest_id)
		if step.get("kind") == "talk" and step.get("npc") == npc_id:
			_advance(player, quest_id, events)
			return
		if step.get("kind") == "deliver" and step.get("npc") == npc_id and _carries(player, step["items"]):
			_deliver(player, quest_id, step, events)
			return
	for quest_id in ContentDB.quest_ids():
		var quest := ContentDB.quest(quest_id)
		if quest["giver"] != npc_id:
			continue
		match status(player, quest_id):
			"in_progress":
				var lines: Array = current_step(player, quest_id).get("remind", [])
				_dialogue(player, npc_id, lines if not lines.is_empty() else [current_step(player, quest_id)["log"]], events)
				return
			"not_started":
				var unmet := unmet_requirement(player, quest_id)
				if not unmet.is_empty():
					_dialogue(player, npc_id, ["Come back when you have %s." % unmet], events)
				else:
					_start(player, quest_id, events)
				return
	_dialogue(player, npc_id, ContentDB.npc(npc_id).get("idle", ["..."]), events)


## Each tick: reach steps finish when the player gets there.
func process(players: Array, events: Array) -> void:
	for player: Combatant in players:
		for quest_id in player.quests:
			var step := current_step(player, quest_id)
			if step.get("kind") != "reach" or not player.is_alive():
				continue
			var at := Vector2(step["at"][0], step["at"][1])
			if Vector2(player.position.x, player.position.z).distance_to(at) <= step["radius"]:
				_advance(player, quest_id, events)


## Called by combat for every attack a player makes.
func on_attack(player: Combatant, target: Combatant, kind: String, events: Array) -> void:
	for quest_id in player.quests:
		var step := current_step(player, quest_id)
		if step.get("kind") == "attack" and step.get("combat") == kind and step.get("tag") == target.tag:
			_progress(player, quest_id, step, events)


## Called when a player is credited with a kill.
func on_kill(player: Combatant, victim: Combatant, events: Array) -> void:
	for quest_id in player.quests:
		var step := current_step(player, quest_id)
		if step.get("kind") == "kill" and step.get("monster") == victim.monster_id:
			_progress(player, quest_id, step, events)


static func _carries(player: Combatant, entries: Array) -> bool:
	return entries.all(func(entry): return player.inventory.count(entry["item"]) >= entry["quantity"])


func _deliver(player: Combatant, quest_id: String, step: Dictionary, events: Array) -> void:
	var handed := []
	for entry in step["items"]:
		player.inventory.remove(entry["item"], entry["quantity"])
		handed.append("%d %s" % [entry["quantity"], ContentDB.item(entry["item"])["name"].to_lower()])
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
	var giver: String = ContentDB.quest(quest_id)["giver"]
	_advance(player, quest_id, events)
	var lines: Array = ["You hand over %s." % " and ".join(handed)]
	lines.append_array(current_step(player, quest_id).get("remind", []))
	_dialogue(player, giver, lines, events)


func _start(player: Combatant, quest_id: String, events: Array) -> void:
	var quest := ContentDB.quest(quest_id)
	player.quests[quest_id] = {"step": 0, "progress": 0, "done": false}
	_dialogue(player, quest["giver"], quest["start"], events)
	for entry in quest.get("start_items", []):
		sim.give_item(player.id, entry["item"], entry["quantity"], "quest", events)
	events.append({"type": "quest_started", "id": player.id, "quest": quest_id, "tick": sim.tick})
	sim.message(player, "Quest started: %s" % quest["name"], events)


func _progress(player: Combatant, quest_id: String, step: Dictionary, events: Array) -> void:
	var state: Dictionary = player.quests[quest_id]
	state["progress"] += 1
	events.append({"type": "quest_progress", "id": player.id, "quest": quest_id, "progress": state["progress"],
		"count": step["count"], "tick": sim.tick})
	if state["progress"] >= step["count"]:
		_advance(player, quest_id, events)


func _advance(player: Combatant, quest_id: String, events: Array) -> void:
	var quest := ContentDB.quest(quest_id)
	var state: Dictionary = player.quests[quest_id]
	state["step"] += 1
	state["progress"] = 0
	if state["step"] >= quest["steps"].size():
		_complete(player, quest_id, events)
		return
	var step: Dictionary = quest["steps"][state["step"]]
	events.append({"type": "quest_step", "id": player.id, "quest": quest_id, "step": state["step"], "tick": sim.tick})
	sim.message(player, step["log"], events)


func _complete(player: Combatant, quest_id: String, events: Array) -> void:
	var quest := ContentDB.quest(quest_id)
	var state: Dictionary = player.quests[quest_id]
	state["done"] = true
	state["step"] = quest["steps"].size()
	_dialogue(player, quest["giver"], quest["complete"], events)
	var rewards: Dictionary = quest["rewards"]
	for skill in rewards.get("xp", {}):
		sim.award_xp(player, skill, float(rewards["xp"][skill]), events)
	for entry in rewards.get("items", []):
		sim.give_item(player.id, entry["item"], entry["quantity"], "quest", events)
	events.append({"type": "quest_complete", "id": player.id, "quest": quest_id, "tick": sim.tick})
	sim.message(player, "Quest complete: %s!" % quest["name"], events)


func _dialogue(player: Combatant, npc_id: String, lines: Array, events: Array) -> void:
	events.append({"type": "dialogue", "id": player.id, "npc": npc_id, "speaker": ContentDB.npc(npc_id).get("name", npc_id),
		"lines": lines.duplicate(), "tick": sim.tick})
