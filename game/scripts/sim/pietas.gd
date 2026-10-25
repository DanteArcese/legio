extends RefCounted
## Pietas: favour, blessings, altars, and offerings.
##
## Favour is the resource blessings spend, up to the Pietas level, and is
## restored by praying at an altar. Each active blessing drains one point
## every drain_ticks. Blessings share aspects (strength, defence, ranged,
## ritus, movement, withering, binding); turning one on replaces another of
## the same aspect. Offerings at an altar train Pietas, one every few ticks;
## the wrong kind of altar gives half the XP.

const ContentDB := preload("res://scripts/content/content_db.gd")

const ALTAR_RANGE := 2.5
const OFFER_TICKS := 3
const WRONG_ALTAR_XP := 0.5

var sim: RefCounted
## [{"kind": "heavenly" | "underworld", "position": Vector3}]
var altars: Array[Dictionary] = []


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


func add_altar(kind: String, position: Vector3) -> void:
	altars.append({"kind": kind, "position": position})


static func max_favour(player: RefCounted) -> float:
	return float(player.skills.level("pietas"))


## Turns a blessing on (replacing any of the same aspect) or off.
func toggle(player: RefCounted, blessing_id: String, events: Array) -> void:
	var blessing := ContentDB.blessing(blessing_id)
	if blessing.is_empty():
		return
	if player.blessings.has(blessing_id):
		player.blessings.erase(blessing_id)
		_changed(player, events)
		return
	if player.skills.level("pietas") < blessing["level"]:
		sim.message(player, "You need Pietas %d for the %s." % [blessing["level"], blessing["name"]], events)
		return
	if player.favour <= 0.0:
		sim.message(player, "You have no favour left. Pray at an altar.", events)
		return
	for other in player.blessings.duplicate():
		if ContentDB.blessing(other)["aspect"] == blessing["aspect"]:
			player.blessings.erase(other)
	player.blessings.append(blessing_id)
	_changed(player, events)


## Praying at an altar restores favour to full.
func pray(player: RefCounted, events: Array) -> void:
	var altar := nearby_altar(player.position)
	if altar.is_empty():
		return
	player.favour = max_favour(player)
	sim.message(player, "You pray at the %s. Your favour is restored." % ContentDB.data()["pietas"]["altars"][altar["kind"]]["name"], events)
	events.append({"type": "favour_changed", "id": player.id, "tick": sim.tick})


## Starts offering every item of one kind at the nearby altar.
func start_offering(player: RefCounted, item_id: String, events: Array) -> void:
	var altar := nearby_altar(player.position)
	if altar.is_empty() or ContentDB.offering(item_id).is_empty():
		return
	if player.inventory.count(item_id) == 0:
		return
	player.target_id = -1
	player.skill_action = {"type": "offer", "item": item_id, "altar": altar, "next_tick": sim.tick + OFFER_TICKS}


func nearby_altar(position: Vector3) -> Dictionary:
	for altar in altars:
		if Vector2(altar["position"].x - position.x, altar["position"].z - position.z).length() <= ALTAR_RANGE:
			return altar
	return {}


static func offering_xp(item_id: String, altar_kind: String) -> float:
	var offering := ContentDB.offering(item_id)
	if offering.is_empty():
		return 0.0
	return offering["xp"] * (1.0 if offering["altar"] == altar_kind else WRONG_ALTAR_XP)


## Per tick: drain favour for active blessings, and run offerings.
func process(players: Array, events: Array) -> void:
	for player in players:
		if not player.blessings.is_empty():
			_drain(player, events)
		var action: Dictionary = player.skill_action
		if action.get("type", "") == "offer":
			_process_offering(player, action, events)


func _drain(player: RefCounted, events: Array) -> void:
	if not player.is_alive():
		player.blessings.clear()
		_changed(player, events)
		return
	for blessing_id in player.blessings:
		player.favour -= 1.0 / ContentDB.blessing(blessing_id)["drain_ticks"]
	if player.favour <= 0.0:
		player.favour = 0.0
		player.blessings.clear()
		sim.message(player, "Your favour is spent. Your blessings fade.", events)
		_changed(player, events)


func _process_offering(player: RefCounted, action: Dictionary, events: Array) -> void:
	var altar: Dictionary = action["altar"]
	if Vector2(altar["position"].x - player.position.x, altar["position"].z - player.position.z).length() > ALTAR_RANGE:
		player.skill_action = {}
		return
	if sim.tick < action["next_tick"]:
		return
	action["next_tick"] = sim.tick + OFFER_TICKS
	var item_id: String = action["item"]
	if player.inventory.remove(item_id, 1) == 0:
		player.skill_action = {}
		return
	sim.award_xp(player, "pietas", offering_xp(item_id, altar["kind"]), events)
	events.append({"type": "offered", "id": player.id, "item": item_id, "altar": altar["kind"], "tick": sim.tick})
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
	if player.inventory.count(item_id) == 0:
		player.skill_action = {}


## Recomputes the player's blessing boosts after a change.
func _changed(player: RefCounted, events: Array) -> void:
	var boosts := {}
	for blessing_id in player.blessings:
		var boost: Dictionary = ContentDB.blessing(blessing_id)["boost"]
		for key in boost:
			boosts[key] = boosts.get(key, 0.0) + boost[key]
	player.blessing_boosts = boosts
	events.append({"type": "blessings_changed", "id": player.id, "tick": sim.tick})
