extends RefCounted
## Pietas: favour, blessings, altars, and offerings.
##
## Favour is the resource blessings spend, up to the Pietas level, and is
## restored by praying at an altar. Each active blessing drains one point
## every drain_ticks. Blessings share aspects (strength, defence, ranged,
## ritus, movement, withering, binding); turning one on replaces another of
## the same aspect. Offerings at an altar train Pietas, one every few ticks;
## the wrong kind of altar gives half the XP.
##
## Pollution: casting curses builds ritual pollution, which wears off over
## time. While polluted, heavenly blessings work at half strength and the
## heavenly altar turns you away, but underworld blessings grow stronger.
## Washing in a sacred spring or a cleansing from the sacerdos clears it.
## Casting curses inside the town walls draws the vigiles: first a warning,
## then a fine.

const ContentDB := preload("res://scripts/content/content_db.gd")

const ALTAR_RANGE := 2.5
const OFFER_TICKS := 3
const WRONG_ALTAR_XP := 0.5

const POLLUTION_PER_CURSE := 4.0
const MAX_POLLUTION := 100.0
const POLLUTION_DECAY_TICKS := 25
const POLLUTED_AT := 30.0
const POLLUTED_HEAVENLY := 0.5
const POLLUTED_UNDERWORLD := 1.5
const WASH_TICKS := 5
## Measured from the spring's centre; the pond is about 4.5 m across.
const SPRING_RANGE := 6.0
const CLEANSING_FEE := 20
const PRIEST_RANGE := 3.0
## The town walls (x, z). Underground areas lie far outside them.
const TOWN := Rect2(-20, -20, 40, 40)
## A second offence within this many ticks of a warning is fined.
const WATCH_MEMORY_TICKS := 500
const WATCH_FINE := 25
## The watch fines at most once per this many ticks (a minute).
const WATCH_FINE_COOLDOWN := 100

## Held weakly: the simulation owns this module, so a strong reference back
## would form a cycle that is never freed.
var sim: RefCounted:
	get:
		return _sim_ref.get_ref()
	set(value):
		_sim_ref = weakref(value)
var _sim_ref: WeakRef
## [{"kind": "heavenly" | "underworld", "position": Vector3}]
var altars: Array[Dictionary] = []
var springs: Array[Vector3] = []
var priest_position: Variant = null


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


func add_altar(kind: String, position: Vector3, consecrates := false) -> void:
	altars.append({"kind": kind, "position": position, "consecrates": consecrates})


## Consecrates a kind of jewellery (a neck piece) the player has, once and for
## good: every one of them they wear gives the consecration's bonus.
func consecrate(player: RefCounted, item_id: String, events: Array) -> void:
	var rules: Dictionary = ContentDB.data()["pietas"].get("consecration", {})
	var altar := nearby_altar(player.position)
	if rules.is_empty() or altar.is_empty() or not altar.get("consecrates", false):
		return
	if not consecratable(item_id):
		sim.message(player, "The priests consecrate jewellery, nothing else.", events)
		return
	if player.consecrated.has(item_id):
		sim.message(player, "Your %s are already consecrated." % ContentDB.item(item_id)["name"].to_lower(), events)
		return
	if player.skills.level("pietas") < rules["level"]:
		sim.message(player, "The priests consecrate for the devout: you need Pietas %d." % rules["level"], events)
		return
	if player.inventory.count(item_id) == 0 and not player.equipment.is_wearing(item_id):
		return
	if player.inventory.count("coins") < rules["fee"]:
		sim.message(player, "The priests ask %d denarii for the rite." % rules["fee"], events)
		return
	player.inventory.remove("coins", rules["fee"])
	player.consecrated.append(item_id)
	player.apply_equipment()
	sim.message(player, "The priest anoints your %s and speaks the rite over it. It's Jupiter's now, as well as yours." % ContentDB.item(item_id)["name"].to_lower(), events)
	events.append({"type": "equipment_changed", "id": player.id, "tick": sim.tick})
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})


## Jewellery: anything worn at the neck.
static func consecratable(item_id: String) -> bool:
	return ContentDB.item(item_id).get("equip", {}).get("slot", "") == "neck"


func add_spring(position: Vector3) -> void:
	springs.append(position)


func set_priest(position: Vector3) -> void:
	priest_position = position


static func is_polluted(player: RefCounted) -> bool:
	return player.pollution >= POLLUTED_AT


## Called whenever a player casts a curse.
func on_curse(player: RefCounted, events: Array) -> void:
	var was_polluted := is_polluted(player)
	player.pollution = minf(player.pollution + POLLUTION_PER_CURSE, MAX_POLLUTION)
	if is_polluted(player) and not was_polluted:
		sim.message(player, "The taint of the underworld clings to you.", events)
		_changed(player, events)
	events.append({"type": "pollution_changed", "id": player.id, "tick": sim.tick})
	var p := Vector2(player.position.x, player.position.z)
	if TOWN.has_point(p):
		town_watch(player, events, "A vigil glares at you: \"No curses within the walls, citizen. That's your only warning.\"",
			"cursing inside the walls")


static func in_town(position: Vector3) -> bool:
	return TOWN.has_point(Vector2(position.x, position.z))


## The vigiles saw an offence: a warning first, then fines for repeat
## offences while they remember you (at most one fine a minute).
func town_watch(player: RefCounted, events: Array, warning: String, offence: String) -> void:
	if player.watch_warned_at == -1 or sim.tick - player.watch_warned_at > WATCH_MEMORY_TICKS:
		player.watch_warned_at = sim.tick
		sim.message(player, warning, events)
		events.append({"type": "watch_warning", "id": player.id, "tick": sim.tick})
		return
	player.watch_warned_at = sim.tick
	if player.watch_fined_at != -1 and sim.tick - player.watch_fined_at < WATCH_FINE_COOLDOWN:
		return
	var fine: int = mini(WATCH_FINE, player.inventory.count("coins"))
	player.inventory.remove("coins", fine)
	player.watch_fined_at = sim.tick
	sim.message(player, "The vigiles fine you %d denarii for %s." % [fine, offence], events)
	events.append({"type": "watch_fine", "id": player.id, "amount": fine, "tick": sim.tick})
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})


## Starts washing in a nearby sacred spring.
func start_washing(player: RefCounted, events: Array) -> void:
	if not springs.any(func(at): return _distance(at, player.position) <= SPRING_RANGE):
		return
	player.target_id = -1
	player.skill_action = {"type": "wash", "next_tick": sim.tick + WASH_TICKS}
	sim.message(player, "You wash in the sacred spring.", events)


## Pays the sacerdos to cleanse pollution.
func cleanse(player: RefCounted, events: Array) -> void:
	if priest_position == null or _distance(priest_position, player.position) > PRIEST_RANGE:
		return
	if player.pollution <= 0.0:
		sim.message(player, "\"You're already clean,\" the sacerdos says.", events)
		return
	if player.inventory.count("coins") < CLEANSING_FEE:
		sim.message(player, "A cleansing costs %d denarii." % CLEANSING_FEE, events)
		return
	player.inventory.remove("coins", CLEANSING_FEE)
	_purify(player, events)
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})


func _purify(player: RefCounted, events: Array) -> void:
	var was_polluted := is_polluted(player)
	player.pollution = 0.0
	sim.message(player, "You are cleansed of the underworld's taint.", events)
	events.append({"type": "pollution_changed", "id": player.id, "tick": sim.tick})
	if was_polluted:
		_changed(player, events)


static func _distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


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
	if altar.is_empty() or _refused(player, altar, events):
		return
	player.favour = max_favour(player)
	sim.message(player, "You pray at the %s. Your favour is restored." % ContentDB.data()["pietas"]["altars"][altar["kind"]]["name"], events)
	events.append({"type": "favour_changed", "id": player.id, "tick": sim.tick})


## Starts offering every item of one kind at the nearby altar.
func start_offering(player: RefCounted, item_id: String, events: Array) -> void:
	var altar := nearby_altar(player.position)
	if altar.is_empty() or ContentDB.offering(item_id).is_empty() or _refused(player, altar, events):
		return
	if player.inventory.count(item_id) == 0:
		return
	player.target_id = -1
	player.skill_action = {"type": "offer", "item": item_id, "altar": altar, "next_tick": sim.tick + OFFER_TICKS}


## The heavenly altar turns away the polluted.
func _refused(player: RefCounted, altar: Dictionary, events: Array) -> bool:
	if altar["kind"] == "heavenly" and is_polluted(player):
		sim.message(player, "The gods turn from you until you are cleansed.", events)
		return true
	return false


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
		if player.pollution > 0.0 and sim.tick % POLLUTION_DECAY_TICKS == 0:
			var was_polluted := is_polluted(player)
			player.pollution = maxf(player.pollution - 1.0, 0.0)
			events.append({"type": "pollution_changed", "id": player.id, "tick": sim.tick})
			if was_polluted and not is_polluted(player):
				_changed(player, events)
		var action: Dictionary = player.skill_action
		match action.get("type", ""):
			"offer":
				_process_offering(player, action, events)
			"wash":
				if sim.tick >= action["next_tick"]:
					player.skill_action = {}
					_purify(player, events)


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
	var polluted := is_polluted(player)
	for blessing_id in player.blessings:
		var blessing := ContentDB.blessing(blessing_id)
		var strength := 1.0
		if polluted:
			strength = POLLUTED_HEAVENLY if blessing["family"] == "heavenly" else POLLUTED_UNDERWORLD
		var boost: Dictionary = blessing["boost"]
		for key in boost:
			boosts[key] = boosts.get(key, 0.0) + boost[key] * strength
	player.blessing_boosts = boosts
	events.append({"type": "blessings_changed", "id": player.id, "tick": sim.tick})
