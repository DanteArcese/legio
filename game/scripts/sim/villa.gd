extends RefCounted
## The villa: citizens buy one from the land surveyor, then build furniture
## at fixed hotspots with Engineering. Furniture is the real thing: a hearth
## is a cooking station, a strongbox is a bank, a lararium is an altar, a
## garden bed is a farming patch. A hired steward runs the presses on real
## time, even while the game is closed, for the owner to collect.

const Combatant := preload("res://scripts/sim/combatant.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const SURVEYOR_RANGE := 3.0
const BUILD_RANGE := 3.0
## Farming patch ids for garden beds, clear of the fixed patches.
const PATCH_ID_BASE := 1000
## The steward fills one amphora per press this often (real seconds), and
## keeps at most a day's worth waiting.
const STEWARD_SECONDS_PER_AMPHORA := 7200.0
const STEWARD_MAX_SECONDS := 86400.0
## What the steward makes with each press.
const STEWARD_GOODS := {"olive_press": "olive_oil", "wine_press": "estate_wine"}

## Held weakly: the simulation owns this module, so a strong reference back
## would form a cycle that is never freed.
var sim: RefCounted:
	get:
		return _sim_ref.get_ref()
	set(value):
		_sim_ref = weakref(value)
var _sim_ref: WeakRef
## hotspot id (e.g. "garden_1") -> {"id", "type", "position", "index"}
var hotspots := {}
var surveyor_position: Variant = null


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


func add_hotspot(hotspot_id: String, hotspot_type: String, position: Vector3) -> void:
	hotspots[hotspot_id] = {"id": hotspot_id, "type": hotspot_type, "position": position, "index": hotspots.size()}


func set_surveyor(position: Vector3) -> void:
	surveyor_position = position


## Furniture that can go on this hotspot, in content order.
static func options_for(hotspot_type: String) -> Array:
	var out := []
	var furniture: Dictionary = ContentDB.data()["villa"]["furniture"]
	for furniture_id in furniture:
		if furniture[furniture_id]["hotspot"] == hotspot_type:
			out.append(furniture_id)
	return out


## Why the player can't buy a villa, or "".
static func purchase_problem(player: Combatant) -> String:
	var villa: Dictionary = ContentDB.data()["villa"]
	if player.villa_owned:
		return "You already own a villa."
	var quest_id: String = villa.get("requires_quest", "")
	if not quest_id.is_empty() and not player.quests.get(quest_id, {}).get("done", false):
		return "Only Roman citizens may own land in the province."
	if player.inventory.count("coins") < villa["price"]:
		return "A villa costs %d denarii." % villa["price"]
	return ""


func buy(player: Combatant, events: Array) -> void:
	if surveyor_position == null or sim.flat_distance(surveyor_position, player.position) > SURVEYOR_RANGE:
		return
	var problem := purchase_problem(player)
	if not problem.is_empty():
		sim.message(player, problem, events)
		return
	player.inventory.remove("coins", ContentDB.data()["villa"]["price"])
	player.villa_owned = true
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
	events.append({"type": "villa_bought", "id": player.id, "tick": sim.tick})
	sim.message(player, "The land is yours. Take the east road from the fort to your villa.", events)


## Why this furniture can't be built here now, or "".
func build_problem(player: Combatant, hotspot_id: String, furniture_id: String) -> String:
	var furniture := ContentDB.furniture(furniture_id)
	if not player.villa_owned or furniture.is_empty() or furniture["hotspot"] != hotspots[hotspot_id]["type"]:
		return "That can't go there."
	if player.villa_furniture.has(hotspot_id):
		return "Remove what's there first."
	if player.skills.level("engineering") < furniture["level"]:
		return "You need Engineering %d to build that." % furniture["level"]
	if player.inventory.count("hammer") == 0:
		return "You need a hammer to build."
	for entry in furniture["materials"]:
		if player.inventory.count(entry["item"]) < entry["quantity"]:
			return "You need %d %s." % [entry["quantity"], ContentDB.item(entry["item"])["name"].to_lower()]
	return ""


## now: real time in seconds, which starts a newly hired steward's books.
func build(player: Combatant, hotspot_id: String, furniture_id: String, events: Array, now := 0.0) -> void:
	if not hotspots.has(hotspot_id) or sim.flat_distance(hotspots[hotspot_id]["position"], player.position) > BUILD_RANGE:
		return
	var problem := build_problem(player, hotspot_id, furniture_id)
	if not problem.is_empty():
		sim.message(player, problem, events)
		return
	var furniture := ContentDB.furniture(furniture_id)
	for entry in furniture["materials"]:
		player.inventory.remove(entry["item"], entry["quantity"])
	player.villa_furniture[hotspot_id] = furniture_id
	_provide(hotspot_id, furniture_id)
	if furniture["provides"].has("steward"):
		player.steward_since = now
	sim.award_xp(player, "engineering", furniture["xp"], events)
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
	events.append(_built_event(player, hotspot_id))
	sim.message(player, "You build a %s." % furniture["name"].to_lower(), events)


func remove(player: Combatant, hotspot_id: String, events: Array) -> void:
	if not player.villa_furniture.has(hotspot_id) or sim.flat_distance(hotspots[hotspot_id]["position"], player.position) > BUILD_RANGE:
		return
	_withdraw(hotspot_id, player.villa_furniture[hotspot_id])
	player.villa_furniture.erase(hotspot_id)
	events.append({"type": "furniture_removed", "id": player.id, "hotspot": hotspot_id, "tick": sim.tick})
	sim.message(player, "You clear the space.", events)


## The goods the steward makes: one item per built press, in hotspot order.
func steward_goods(player: Combatant) -> Array:
	var goods := []
	for hotspot_id in player.villa_furniture:
		var station: String = ContentDB.furniture(player.villa_furniture[hotspot_id])["provides"].get("station", "")
		if STEWARD_GOODS.has(station):
			goods.append(STEWARD_GOODS[station])
	return goods


func has_steward(player: Combatant) -> bool:
	return player.villa_furniture.values().any(func(f): return ContentDB.furniture(f)["provides"].has("steward"))


## How many amphorae of each good are waiting at real time now.
func steward_ready(player: Combatant, now: float) -> int:
	if not has_steward(player):
		return 0
	var elapsed := clampf(now - player.steward_since, 0.0, STEWARD_MAX_SECONDS)
	return floori(elapsed / STEWARD_SECONDS_PER_AMPHORA)


## Hands over what the steward has made since the last visit. Time beyond
## the day's cap is lost; part of an amphora carries over.
func collect(player: Combatant, now: float, events: Array) -> void:
	var office := _steward_hotspot(player)
	if office.is_empty() or sim.flat_distance(hotspots[office]["position"], player.position) > BUILD_RANGE:
		return
	var goods := steward_goods(player)
	if goods.is_empty():
		sim.message(player, "\"Without a press, master, there's nothing for me to sell.\"", events)
		return
	var ready := steward_ready(player, now)
	if ready == 0:
		var wait := STEWARD_SECONDS_PER_AMPHORA - fmod(maxf(now - player.steward_since, 0.0), STEWARD_SECONDS_PER_AMPHORA)
		sim.message(player, "\"Nothing sealed yet. Give it %d minutes or so.\"" % ceili(wait / 60.0), events)
		return
	if now - player.steward_since >= STEWARD_MAX_SECONDS:
		player.steward_since = now
	else:
		player.steward_since += ready * STEWARD_SECONDS_PER_AMPHORA
	var parts := []
	for item_id in goods:
		sim.give_item(player.id, item_id, ready, "villa", events)
		parts.append("%d %s" % [ready, ContentDB.item(item_id)["name"].to_lower()])
	sim.message(player, "Your steward hands over %s." % " and ".join(parts), events)


func _steward_hotspot(player: Combatant) -> String:
	for hotspot_id in player.villa_furniture:
		if hotspots.has(hotspot_id) and ContentDB.furniture(player.villa_furniture[hotspot_id])["provides"].has("steward"):
			return hotspot_id
	return ""


## After loading a save: put back what the furniture provides.
func restore(player: Combatant, events: Array) -> void:
	for hotspot_id in player.villa_furniture:
		if hotspots.has(hotspot_id):
			_provide(hotspot_id, player.villa_furniture[hotspot_id])
			events.append(_built_event(player, hotspot_id))


static func patch_id(hotspot: Dictionary) -> int:
	return PATCH_ID_BASE + hotspot["index"]


func _built_event(player: Combatant, hotspot_id: String) -> Dictionary:
	return {"type": "furniture_built", "id": player.id, "hotspot": hotspot_id, "furniture": player.villa_furniture[hotspot_id], "tick": sim.tick}


func _provide(hotspot_id: String, furniture_id: String) -> void:
	var hotspot: Dictionary = hotspots[hotspot_id]
	var provides: Dictionary = ContentDB.furniture(furniture_id)["provides"]
	if provides.has("station"):
		sim.skilling.add_station(provides["station"], hotspot["position"])
	elif provides.has("bank"):
		sim.items.banks.append(hotspot["position"])
	elif provides.has("altar"):
		sim.pietas.add_altar(provides["altar"], hotspot["position"])
	elif provides.has("patch"):
		sim.farming.add_patch(patch_id(hotspot), provides["patch"], "Villa_" + hotspot_id, hotspot["position"])


func _withdraw(hotspot_id: String, furniture_id: String) -> void:
	var hotspot: Dictionary = hotspots[hotspot_id]
	var at: Vector3 = hotspot["position"]
	var provides: Dictionary = ContentDB.furniture(furniture_id)["provides"]
	if provides.has("station"):
		_remove_at(sim.skilling.stations, at)
	elif provides.has("bank"):
		sim.items.banks.erase(at)
	elif provides.has("altar"):
		_remove_at(sim.pietas.altars, at)
	elif provides.has("patch"):
		sim.farming.patches.erase(patch_id(hotspot))


## Drops entries at a position from a typed list, in place.
static func _remove_at(list: Array, at: Vector3) -> void:
	for i in range(list.size() - 1, -1, -1):
		if list[i]["position"] == at:
			list.remove_at(i)
