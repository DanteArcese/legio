extends RefCounted
## Chariot racing in the circuses (Athletics): the frontier's circus east of
## the fort ("castra") and the Circus Maximus in Rome ("maximus"), each with
## its own track, agent and rules in circus.json. A factio agent enters you in
## a race against rival chariots: a few ticks' countdown, then laps of an
## oval track round the spina. You drive; the rivals hold a steady pace on
## the racing line, so their finishing ticks are known from the start, and
## your place is how many of them you beat to the line.
##
## The track is an oval along the x axis: straights at z = centre +- radius
## joined by half circles round (centre.x +- half, centre.z). Progress s runs
## from the start line (the middle of the +z straight) towards +x, round the
## east turn, back along the -z straight, and round the west turn. A lap
## counts when you pass through each quarter of the track in order and back
## across the line, so cutting across can't count.

const Combatant := preload("res://scripts/sim/combatant.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const TICK_SECONDS := 0.6
## How close to the agent you must be to enter.
const AGENT_RANGE := 3.0
## Leave the track by this much and the race is abandoned.
const LEAVE_MARGIN := 15.0
## Chariots start a little past the line, a lane apart.
const START_PROGRESS := 2.0
const LANE_WIDTH := 2.6
const ORDINALS := ["first", "second", "third", "fourth", "fifth"]

## Held weakly: the simulation owns this module, so a strong reference back
## would form a cycle that is never freed.
var sim: RefCounted:
	get:
		return _sim_ref.get_ref()
	set(value):
		_sim_ref = weakref(value)
var _sim_ref: WeakRef
## circus id -> {"center": Vector3, "half": float, "radius": float}, set by the world.
var tracks := {}
## circus id -> where its factio agent stands.
var agents := {}


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


## A circus's rules (the frontier's unless named).
static func data(circus_id := "castra") -> Dictionary:
	return ContentDB.data()["circus"]["circuses"][circus_id]


func set_track(center: Vector3, half: float, radius: float, circus_id := "castra") -> void:
	tracks[circus_id] = {"center": center, "half": half, "radius": radius}


func set_agent(position: Vector3, circus_id := "castra") -> void:
	agents[circus_id] = position


## The track a player is racing on, or the frontier's.
func track_of(player: Combatant) -> Dictionary:
	return tracks.get(player.race.get("circus", "castra"), {})


static func lap_length(t: Dictionary) -> float:
	return 4.0 * t["half"] + TAU * t["radius"]


## Where along the lap (0 to lap_length) a point lies.
static func progress(t: Dictionary, p: Vector3) -> float:
	var h: float = t["half"]
	var r: float = t["radius"]
	var dx: float = p.x - t["center"].x
	var dz: float = p.z - t["center"].z
	if dx > h:
		return h + atan2(dx - h, dz) * r
	if dx < -h:
		return 3.0 * h + PI * r + atan2(-(dx + h), -dz) * r
	if dz >= 0.0:
		return dx if dx >= 0.0 else lap_length(t) + dx
	return h + PI * r + (h - dx)


## The point at progress s, lane metres outward from the racing line.
static func point_at(t: Dictionary, s: float, lane := 0.0) -> Vector3:
	var h: float = t["half"]
	var r: float = t["radius"] + lane
	var base: float = t["radius"]
	var c: Vector3 = t["center"]
	s = fposmod(s, lap_length(t))
	if s < h:
		return c + Vector3(s, 0, r)
	if s < h + PI * base:
		var angle := (s - h) / base
		return c + Vector3(h + sin(angle) * r, 0, cos(angle) * r)
	if s < 3.0 * h + PI * base:
		return c + Vector3(h - (s - h - PI * base), 0, -r)
	if s < 3.0 * h + TAU * base:
		var angle := (s - 3.0 * h - PI * base) / base
		return c + Vector3(-h - sin(angle) * r, 0, -cos(angle) * r)
	return c + Vector3(s - lap_length(t), 0, r)


static func chariot_speed(level: int, circus_id := "castra") -> float:
	var rules := data(circus_id)
	return rules["speed"] * (1.0 + level * rules["speed_per_level"])


static func is_racing(player: Combatant) -> bool:
	return not player.race.is_empty()


## Ticks a rival takes to finish every lap from the start.
func rival_ticks(rival: Dictionary, circus_id := "castra") -> int:
	return ceili(data(circus_id)["laps"] * lap_length(tracks[circus_id]) / rival["speed"] / TICK_SECONDS)


## Why the player can't race now, or "".
func start_problem(player: Combatant, circus_id := "castra") -> String:
	var rules := data(circus_id)
	if player.skills.level("athletics") < rules["level"]:
		return "You need Athletics %d to drive a chariot." % rules["level"]
	if player.inventory.count("coins") < rules["fee"]:
		return "The entry fee is %d denarii." % rules["fee"]
	return ""


## Enters the player in a race at whichever circus's agent they're beside.
func start(player: Combatant, events: Array) -> void:
	if is_racing(player):
		return
	var circus_id := ""
	for id in agents:
		if tracks.has(id) and sim.flat_distance(agents[id], player.position) <= AGENT_RANGE:
			circus_id = id
	if circus_id.is_empty():
		return
	var problem := start_problem(player, circus_id)
	if not problem.is_empty():
		sim.message(player, problem, events)
		return
	var rules := data(circus_id)
	player.inventory.remove("coins", rules["fee"])
	player.target_id = -1
	player.move_target = null
	player.skill_action = {}
	var begins: int = sim.tick + rules["countdown_ticks"]
	var finishes := []
	for rival in rules["rivals"]:
		finishes.append(begins + rival_ticks(rival, circus_id))
	player.race = {"circus": circus_id, "start": begins, "lap": 0, "sector": 0, "finishes": finishes}
	var grid := point_at(tracks[circus_id], START_PROGRESS)
	player.position = grid
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
	events.append({"type": "race_started", "id": player.id, "start": begins, "position": grid, "tick": sim.tick})
	sim.message(player, "You take the reins. The magistrate raises the white cloth...", events)


func leave(player: Combatant, events: Array) -> void:
	if is_racing(player):
		_end(player, events)
		sim.message(player, "You pull your horses up and leave the track.", events)


func process(players: Array, events: Array) -> void:
	for player: Combatant in players:
		if not is_racing(player):
			continue
		var race: Dictionary = player.race
		var track := track_of(player)
		var rules := data(race.get("circus", "castra"))
		if sim.tick == race["start"]:
			sim.message(player, "The cloth drops. They're off!", events)
		if sim.tick < race["start"]:
			continue
		var c: Vector3 = track["center"]
		var off_track: bool = absf(player.position.x - c.x) > track["half"] + track["radius"] + LEAVE_MARGIN \
			or absf(player.position.z - c.z) > track["radius"] + LEAVE_MARGIN
		if off_track or sim.tick > race["start"] + rules["time_limit_ticks"] or not player.is_alive():
			_end(player, events)
			sim.message(player, "The race goes on without you.", events)
			continue
		var quarter := lap_length(track) / 4.0
		var sector := mini(floori(progress(track, player.position) / quarter), 3)
		if sector != (race["sector"] + 1) % 4:
			continue
		race["sector"] = sector
		if sector != 0:
			continue
		race["lap"] += 1
		sim.award_xp(player, "athletics", rules["lap_xp"], events)
		if race["lap"] >= rules["laps"]:
			_finish(player, events)
		else:
			events.append({"type": "race_lap", "id": player.id, "lap": race["lap"], "tick": sim.tick})
			sim.message(player, "Lap %d of %d." % [race["lap"] + 1, rules["laps"]], events)


## Where the player would place if the race ended now, by distance run.
func live_place(player: Combatant) -> int:
	var race: Dictionary = player.race
	if race.is_empty():
		return 0
	var elapsed := maxf(0.0, (sim.tick - race["start"]) * TICK_SECONDS)
	var track := track_of(player)
	var length := lap_length(track)
	var mine: float = race["lap"] * length + progress(track, player.position)
	var place := 1
	for rival in data(race.get("circus", "castra"))["rivals"]:
		if START_PROGRESS + rival["speed"] * elapsed > mine:
			place += 1
	return place


func _finish(player: Combatant, events: Array) -> void:
	var circus_id: String = player.race.get("circus", "castra")
	var rules := data(circus_id)
	var place := 1
	for finish in player.race["finishes"]:
		if finish < sim.tick:
			place += 1
	_end(player, events)
	sim.award_xp(player, "athletics", rules["placing_xp"][place - 1], events)
	var prize: int = rules["prizes"][place - 1]
	if prize > 0:
		sim.give_item(player.id, "coins", prize, "skilling", events)
	if place == 1:
		sim.give_item(player.id, rules["trophy"], 1, "skilling", events)
		sim.message(player, "You cross the line first! The crowd is on its feet. (%d denarii and a victor's palm)" % prize, events)
		# A season's champion: every few wins here, a crown.
		player.circus_wins[circus_id] = int(player.circus_wins.get(circus_id, 0)) + 1
		var champion: Dictionary = rules.get("champion", {})
		if not champion.is_empty() and player.circus_wins[circus_id] % int(champion["wins"]) == 0:
			sim.give_item(player.id, champion["item"], 1, "skilling", events)
			sim.message(player, "%d wins at the %s: you're the champion of the season, and they crown you with laurel." % [player.circus_wins[circus_id], rules["name"]], events)
	elif prize > 0:
		sim.message(player, "You finish %s. (%d denarii)" % [ORDINALS[place - 1], prize], events)
	else:
		sim.message(player, "You finish %s. The crowd jeers good-naturedly." % ORDINALS[place - 1], events)
	events.append({"type": "race_finished", "id": player.id, "place": place, "tick": sim.tick})


func _end(player: Combatant, events: Array) -> void:
	player.race = {}
	events.append({"type": "race_ended", "id": player.id, "tick": sim.tick})
