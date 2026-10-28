extends RefCounted
## Athletics: running an obstacle course. Each obstacle is a short timed
## crossing from its start to its end. Whether it goes well is rolled when
## the player starts, so the client can show a clean crossing or a fall.
## Clearing every obstacle of a course in order earns a lap bonus. Shortcuts
## are a course with no lap bonus: each one is just a crossing.

const Combatant := preload("res://scripts/sim/combatant.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

## How close to an obstacle's start a player must be.
const START_RANGE := 2.0
## Each level above an obstacle's makes a fall less likely.
const FAIL_PER_LEVEL := 0.01
## Run speed bonus per Athletics level (about +20% at 99).
const SPEED_PER_LEVEL := 0.002

## Held weakly: the simulation owns this module, so a strong reference back
## would form a cycle that is never freed.
var sim: RefCounted:
	get:
		return _sim_ref.get_ref()
	set(value):
		_sim_ref = weakref(value)
var _sim_ref: WeakRef
## obstacle id -> {"id", "course", "index", "start", "end"}
var obstacles := {}


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


func add_obstacle(id: int, course_id: String, index: int, start: Vector3, end: Vector3) -> void:
	obstacles[id] = {"id": id, "course": course_id, "index": index, "start": start, "end": end}


static func obstacle_data(course_id: String, index: int) -> Dictionary:
	return ContentDB.course(course_id)["obstacles"][index]


static func fail_chance(level: int, obstacle: Dictionary) -> float:
	return clampf(obstacle["fail_chance"] - FAIL_PER_LEVEL * (level - obstacle["level"]), 0.0, 0.9)


static func run_speed_bonus(level: int) -> float:
	return level * SPEED_PER_LEVEL


static func is_crossing(player: Combatant) -> bool:
	return not player.obstacle.is_empty()


func start(player: Combatant, obstacle_id: int, events: Array) -> void:
	var obstacle: Dictionary = obstacles.get(obstacle_id, {})
	if obstacle.is_empty() or is_crossing(player) or sim.flat_distance(obstacle["start"], player.position) > START_RANGE:
		return
	var data := obstacle_data(obstacle["course"], obstacle["index"])
	var level: int = player.skills.level("athletics")
	if level < data["level"]:
		sim.message(player, "You need Athletics %d for that." % data["level"], events)
		return
	player.target_id = -1
	var falls: bool = sim.rng.randf() < fail_chance(level, data)
	player.obstacle = {"id": obstacle_id, "until": sim.tick + data["ticks"], "falls": falls}
	events.append({"type": "obstacle_started", "id": player.id, "obstacle": obstacle_id, "falls": falls,
		"from": obstacle["start"], "to": obstacle["end"], "ticks": data["ticks"], "tick": sim.tick})


func process(players: Array, events: Array) -> void:
	for player: Combatant in players:
		if not is_crossing(player) or sim.tick < player.obstacle["until"]:
			continue
		var obstacle: Dictionary = obstacles[player.obstacle["id"]]
		var data := obstacle_data(obstacle["course"], obstacle["index"])
		var falls: bool = player.obstacle["falls"]
		player.obstacle = {}
		if falls:
			var damage: int = mini(sim.rng.randi_range(data["damage"][0], data["damage"][1]), player.hp - 1)
			player.hp -= damage
			player.position = obstacle["start"]
			player.course_next = 0
			events.append({"type": "hit", "attacker": -1, "target": player.id, "damage": damage, "ranged": false, "kind": "melee", "tick": sim.tick})
			events.append({"type": "obstacle_done", "id": player.id, "obstacle": obstacle["id"], "success": false, "tick": sim.tick})
			sim.message(player, "You slip and fall!", events)
			continue
		player.position = obstacle["end"]
		sim.award_xp(player, "athletics", data["xp"], events)
		events.append({"type": "obstacle_done", "id": player.id, "obstacle": obstacle["id"], "success": true, "tick": sim.tick})
		_lap_progress(player, obstacle, events)


## Obstacles cleared in order count toward a lap; any other order starts over.
func _lap_progress(player: Combatant, obstacle: Dictionary, events: Array) -> void:
	var course := ContentDB.course(obstacle["course"])
	if course["lap_xp"] <= 0:
		return
	if obstacle["index"] != player.course_next:
		player.course_next = 1 if obstacle["index"] == 0 else 0
		return
	player.course_next += 1
	if player.course_next >= course["obstacles"].size():
		player.course_next = 0
		player.laps += 1
		sim.award_xp(player, "athletics", course["lap_xp"], events)
		events.append({"type": "lap_complete", "id": player.id, "laps": player.laps, "tick": sim.tick})
		sim.message(player, "Lap complete! (%d laps)" % player.laps, events)
