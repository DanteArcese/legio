extends RefCounted
## The cursus publicus: waystations of the state post along the roads. A
## station is unlocked by walking up to it, and from any unlocked station the
## stationmaster sends you on to any other for its fee. Content in
## waystations.json; the world registers where each stands.

const Combatant := preload("res://scripts/sim/combatant.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

## Held weakly: the simulation owns this module, so a strong reference back
## would form a cycle that is never freed.
var sim: RefCounted:
	get:
		return _sim_ref.get_ref()
	set(value):
		_sim_ref = weakref(value)
var _sim_ref: WeakRef
## station id -> position.
var stations := {}


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


static func data() -> Dictionary:
	return ContentDB.data()["waystations"]


static func station(station_id: String) -> Dictionary:
	return data()["stations"].get(station_id, {})


func add(station_id: String, position: Vector3) -> void:
	stations[station_id] = position


## Unlocks any station a player walks up to.
func process(players: Array, events: Array) -> void:
	var reach: float = data()["unlock_range"]
	for player: Combatant in players:
		for station_id in stations:
			if player.waystations.has(station_id):
				continue
			if sim.flat_distance(stations[station_id], player.position) <= reach:
				player.waystations.append(station_id)
				events.append({"type": "waystation_unlocked", "id": player.id, "station": station_id, "tick": sim.tick})
				sim.message(player, "The stationmaster at %s writes your name in the ledger. You can ride the post from here." % station(station_id)["name"], events)


## The station a player is standing at, or "".
func station_at(player: Combatant) -> String:
	var reach: float = data()["use_range"]
	for station_id in stations:
		if sim.flat_distance(stations[station_id], player.position) <= reach:
			return station_id
	return ""


## Rides the post from the station the player is at to another they've
## unlocked, for the destination's fee.
func travel(player: Combatant, to: String, events: Array) -> void:
	var here := station_at(player)
	if here.is_empty() or here == to or not stations.has(to):
		return
	if not player.waystations.has(to):
		sim.message(player, "You've never been to %s. The post only takes you where you're known." % station(to)["name"], events)
		return
	if not player.games.is_empty() or not player.race.is_empty():
		return
	var fee: int = station(to)["fee"]
	if player.inventory.count("coins") < fee:
		sim.message(player, "The post to %s costs %d denarii." % [station(to)["name"], fee], events)
		return
	player.inventory.remove("coins", fee)
	var at: Vector3 = stations[to] + Vector3(0, 0, 2.0)
	player.target_id = -1
	player.move_target = null
	player.skill_action = {}
	player.position = at
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
	events.append({"type": "teleported", "id": player.id, "position": at, "tick": sim.tick})
	sim.message(player, "You change horses at every station and ride the post to %s. (%d denarii)" % [station(to)["name"], fee], events)
