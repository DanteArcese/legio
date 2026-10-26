extends RefCounted
## Versioned save format for a player. Plain dictionaries, so a server can
## store the same data later. Bump VERSION when the format changes and add
## a step to migrate() so old saves keep loading.

const Skills := preload("res://scripts/sim/skills.gd")

const VERSION := 1


## now is the real time (unix seconds) of the save, so crops can keep
## growing while the game is closed; 0 leaves that out (tests).
static func capture(sim: RefCounted, player_id: int, now := 0) -> Dictionary:
	var player: RefCounted = sim.get_combatant(player_id)
	var grave: Dictionary = sim.grave_of(player_id)
	var saved_grave := {}
	if not grave.is_empty():
		saved_grave = {
			"position": _vec_to_array(grave["position"]),
			"items": grave["items"].duplicate(true),
			"ticks_left": grave["expires_at"] - sim.tick,
		}
	return {
		"version": VERSION,
		"account_mode": player.account_mode,
		"position": _vec_to_array(player.position),
		"hp": player.hp,
		"favour": player.favour,
		"pollution": player.pollution,
		"style": player.style,
		"skills": player.skills.xp.duplicate(),
		"inventory": player.inventory.to_array(),
		"equipment": player.equipment.worn.duplicate(),
		"ammo_count": player.equipment.ammo_count,
		"bank": player.bank.to_array(),
		"slayer": {
			"task": player.slayer_task.duplicate(),
			"points": player.slayer_points,
			"tasks_done": player.slayer_tasks_done,
		},
		"quests": player.quests.duplicate(true),
		"laps": player.laps,
		"trade_contract": player.trade_contract.duplicate(),
		"villa": {"owned": player.villa_owned, "furniture": player.villa_furniture.duplicate()},
		"contracts_done": player.contracts_done,
		"collection": player.collection.duplicate(),
		"saved_at": now,
		"farming": sim.farming.capture(player_id),
		# Traps left out in the world aren't saved; their owner gets them back.
		"traps_out": sim.hunter.traps_out(player_id),
		"grave": saved_grave,
		"reclaimable": sim.reclaimable.get(player_id, []).duplicate(true),
	}


## Applies saved data to an existing player. Returns false if the data is
## unusable (newer than this build, or not a save at all).
## now is the real time of loading: time since the save grows crops.
static func restore(sim: RefCounted, player_id: int, data: Dictionary, now := 0) -> bool:
	data = migrate(data)
	if data.is_empty():
		return false
	var player: RefCounted = sim.get_combatant(player_id)
	player.account_mode = data["account_mode"]
	player.position = _array_to_vec(data["position"])
	for skill in data["skills"]:
		if player.skills.xp.has(skill):
			player.skills.xp[skill] = float(data["skills"][skill])
	player.max_hp = player.skills.level("vitality")
	player.hp = clampi(int(data["hp"]), 1, player.max_hp)
	player.style = data["style"]
	player.pollution = clampf(float(data.get("pollution", 0.0)), 0.0, 100.0)
	player.favour = clampf(float(data.get("favour", player.skills.level("pietas"))), 0.0, float(player.skills.level("pietas")))
	player.inventory.slots.fill(null)
	player.inventory.load_array(_int_quantities(data["inventory"]))
	player.bank.slots.fill(null)
	player.bank.load_array(_int_quantities(data["bank"]))
	for slot in data["equipment"]:
		if player.equipment.worn.has(slot):
			player.equipment.worn[slot] = data["equipment"][slot]
	player.equipment.ammo_count = int(data.get("ammo_count", 0))
	player.apply_equipment()
	var slayer: Dictionary = data["slayer"]
	player.slayer_task = slayer["task"].duplicate()
	if player.slayer_task.has("remaining"):
		player.slayer_task["remaining"] = int(player.slayer_task["remaining"])
		player.slayer_task["total"] = int(player.slayer_task["total"])
	player.slayer_points = int(slayer["points"])
	player.slayer_tasks_done = int(slayer["tasks_done"])
	player.laps = int(data.get("laps", 0))
	player.trade_contract = data.get("trade_contract", {}).duplicate()
	var villa: Dictionary = data.get("villa", {})
	player.villa_owned = bool(villa.get("owned", false))
	player.villa_furniture = villa.get("furniture", {}).duplicate()
	sim.villa.restore(player, [])
	player.contracts_done = int(data.get("contracts_done", 0))
	player.collection = {}
	var collection: Dictionary = data.get("collection", {})
	for item_id in collection:
		player.collection[item_id] = int(collection[item_id])
	sim.farming.restore(player_id, data.get("farming", []), [])
	var saved_at := int(data.get("saved_at", 0))
	if now > 0 and saved_at > 0 and now > saved_at:
		sim.farming.advance(player_id, int((now - saved_at) / sim.farming.TICK_SECONDS), [])
	var traps := int(data.get("traps_out", 0))
	if traps > 0:
		player.inventory.add("box_trap", traps)
	player.quests = {}
	var saved_quests: Dictionary = data.get("quests", {})
	for quest_id in saved_quests:
		var state: Dictionary = saved_quests[quest_id]
		player.quests[quest_id] = {"step": int(state["step"]), "progress": int(state["progress"]), "done": bool(state["done"])}
	var grave: Dictionary = data["grave"]
	if not grave.is_empty():
		sim.restore_grave(player_id, _array_to_vec(grave["position"]), _int_quantities(grave["items"]), int(grave["ticks_left"]))
	if not data["reclaimable"].is_empty():
		sim.reclaimable[player_id] = _int_quantities(data["reclaimable"])
	return true


## Brings older saves up to VERSION. Returns {} for unusable data.
static func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version < 1 or version > VERSION:
		return {}
	# Future: if version == 1: ...convert to 2...; version = 2
	return data


static func to_json(data: Dictionary) -> String:
	return JSON.stringify(data, "  ")


static func from_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


## JSON turns every number into a float; item quantities must be ints.
static func _int_quantities(entries: Array) -> Array:
	return entries.map(func(entry):
		if entry == null:
			return null
		return {"item": entry["item"], "quantity": int(entry["quantity"])})


static func _vec_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _array_to_vec(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
