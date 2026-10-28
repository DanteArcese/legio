extends RefCounted
## The munera: gladiatorial games on the circus's east sands. The editor
## enters a fighter, and waves of beasts and raiders from content are set
## on them one after another, a short rest between each. Every wave cleared
## pays coins; clearing the last wins the trophy. Falling in the arena isn't
## a death: the attendants carry you out with what you've earned. Leaving
## the sands forfeits the rest.
##
## The sim spawns each wave's monsters itself (with ids from a reserved
## range, no respawn and no drops) and tells the world with games_spawn;
## games_despawn takes their bodies away again.

const Combatant := preload("res://scripts/sim/combatant.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

## Combatant ids for arena monsters, clear of everything placed in scenes.
const ID_BASE := 900000
const EDITOR_RANGE := 3.0

## Held weakly: the simulation owns this module, so a strong reference back
## would form a cycle that is never freed.
var sim: RefCounted:
	get:
		return _sim_ref.get_ref()
	set(value):
		_sim_ref = weakref(value)
var _sim_ref: WeakRef
var arena_center: Variant = null
var editor_position: Variant = null
var _next_id := ID_BASE


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


static func data() -> Dictionary:
	return ContentDB.data()["games"]


static func in_games(player: Combatant) -> bool:
	return not player.games.is_empty()


func set_arena(center: Vector3) -> void:
	arena_center = center


func set_editor(position: Vector3) -> void:
	editor_position = position


## Why the player can't enter the games now, or "".
func start_problem(player: Combatant) -> String:
	var needed: int = data()["combat_level"]
	if player.skills.combat_level() < needed:
		return "\"Combat %d at least. The crowd paid to see a fight, not a funeral.\"" % needed
	if not player.race.is_empty():
		return "Finish your race first."
	return ""


func start(player: Combatant, events: Array) -> void:
	if arena_center == null or editor_position == null or in_games(player):
		return
	if sim.flat_distance(editor_position, player.position) > EDITOR_RANGE:
		return
	var problem := start_problem(player)
	if not problem.is_empty():
		sim.message(player, problem, events)
		return
	player.target_id = -1
	player.move_target = null
	player.skill_action = {}
	player.games = {"wave": 0, "alive": [], "spawned": [], "rest_until": sim.tick + data()["rest_ticks"], "earned": 0}
	player.position = arena_center
	events.append({"type": "games_started", "id": player.id, "position": arena_center, "tick": sim.tick})
	sim.message(player, "The trumpets sound. You walk out onto the sand to a roar.", events)


func process(players: Array, events: Array) -> void:
	for player: Combatant in players:
		if not in_games(player):
			continue
		var games: Dictionary = player.games
		if sim.flat_distance(player.position, arena_center) > data()["leave_radius"]:
			_end(player, events, "You run from the sand. The crowd boos you all the way out.")
			continue
		if games["alive"].is_empty():
			if sim.tick >= games["rest_until"]:
				_spawn_wave(player, events)
			continue
		games["alive"] = games["alive"].filter(func(id): return sim.get_combatant(id) != null and sim.get_combatant(id).is_alive())
		if games["alive"].is_empty():
			_wave_cleared(player, events)


## A fall in the arena: caught before it becomes a death. True if handled.
func on_fall(victim: Combatant, events: Array) -> bool:
	if not victim.is_player() or not in_games(victim):
		return false
	victim.hp = victim.max_hp
	victim.curses.clear()
	_end(victim, events, "You go down in the sand. The attendants carry you out, still breathing.")
	return true


func _spawn_wave(player: Combatant, events: Array) -> void:
	var games: Dictionary = player.games
	var wave: Dictionary = data()["waves"][games["wave"]]
	games["wave"] += 1
	var spawned := []
	var count: int = wave["monsters"].size()
	for i in count:
		var monster_id: String = wave["monsters"][i]
		var angle: float = TAU * i / count + games["wave"]
		var at: Vector3 = arena_center + Vector3(cos(angle), 0, sin(angle)) * data()["spawn_radius"]
		var id := _next_id
		_next_id += 1
		var monster: Combatant = sim.add_monster(id, monster_id, at)
		monster.respawn_ticks = -1
		monster.drop_table = ""
		monster.aggressive = true
		monster.target_id = player.id
		games["alive"].append(id)
		games["spawned"].append(id)
		spawned.append({"id": id, "monster": monster_id, "position": at})
	events.append({"type": "games_spawn", "id": player.id, "wave": games["wave"], "monsters": spawned, "tick": sim.tick})
	var names: Array = wave["monsters"].map(func(m): return ContentDB.monster(m)["name"].to_lower())
	sim.message(player, "Wave %d of %d: %s!" % [games["wave"], data()["waves"].size(), ", ".join(names)], events)


func _wave_cleared(player: Combatant, events: Array) -> void:
	var games: Dictionary = player.games
	var wave: Dictionary = data()["waves"][games["wave"] - 1]
	_despawn(player, events)
	if wave["coins"] > 0:
		sim.give_item(player.id, "coins", wave["coins"], "skilling", events)
		games["earned"] += wave["coins"]
	events.append({"type": "games_wave_cleared", "id": player.id, "wave": games["wave"], "tick": sim.tick})
	if games["wave"] > player.games_best:
		player.games_best = games["wave"]
	if games["wave"] >= data()["waves"].size():
		sim.give_item(player.id, data()["trophy"], 1, "skilling", events)
		_end(player, events, "The last beast falls. The editor raises his hand, and an attendant brings you the rudis: freedom, and the crowd's love. (%d denarii in all)" % games["earned"])
		return
	games["rest_until"] = sim.tick + data()["rest_ticks"]
	sim.message(player, "Wave %d cleared! %d denarii. Catch your breath..." % [games["wave"], wave["coins"]], events)


func _despawn(player: Combatant, events: Array) -> void:
	var games: Dictionary = player.games
	if games["spawned"].is_empty():
		return
	for id in games["spawned"]:
		sim.remove_combatant(id)
	events.append({"type": "games_despawn", "id": player.id, "ids": games["spawned"].duplicate(), "tick": sim.tick})
	games["spawned"] = []
	games["alive"] = []


func _end(player: Combatant, events: Array, text: String) -> void:
	_despawn(player, events)
	player.games = {}
	player.target_id = -1
	var exit: Vector3 = editor_position + Vector3(0, 0, 1.5)
	player.position = exit
	events.append({"type": "games_ended", "id": player.id, "position": exit, "tick": sim.tick})
	sim.message(player, text, events)
