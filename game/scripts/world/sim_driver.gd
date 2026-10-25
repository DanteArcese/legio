extends Node
## Runs the simulation on game ticks and relays its events to the scene.
## Press F3 to cycle tick lengths (debug only; the game uses 0.6 s).

const Simulation := preload("res://scripts/sim/simulation.gd")
const TickClock := preload("res://scripts/sim/tick_clock.gd")
const LootPile := preload("res://scripts/world/loot_pile.gd")
const GraveMarker := preload("res://scripts/world/grave_marker.gd")
const Projectile := preload("res://scripts/world/projectile.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

## Entities with entity_id 0 get ids from here up.
const AUTO_ID_START := 1000

signal ticked(tick: int)
signal sim_event(event: Dictionary)

@export var seed_value := 0
@export var tick_lengths: Array[float] = [0.6, 0.5, 0.4]

var sim: Simulation
var clock := TickClock.new()

var _entities := {}
var _next_auto_id := AUTO_ID_START
var _piles := {}
var _graves := {}
var _rocks := {}


func _ready() -> void:
	sim = Simulation.new(seed_value)
	clock.tick_length = tick_lengths[0]
	for entity in get_tree().get_nodes_in_group("sim_entities"):
		register(entity)
	for bank in get_tree().get_nodes_in_group("banks"):
		sim.add_bank(bank.global_position)
	for undertaker in get_tree().get_nodes_in_group("libitinarii"):
		sim.add_libitinarius(undertaker.global_position)
	for venator in get_tree().get_nodes_in_group("venatores"):
		sim.add_venator(venator.get_meta("venator_id"), venator.global_position)
	for rock in get_tree().get_nodes_in_group("rocks"):
		rock.rock_id = _rocks.size() + 1
		_rocks[rock.rock_id] = rock
		sim.skilling.add_rock(rock.rock_id, rock.rock_type, rock.global_position)
	for station in get_tree().get_nodes_in_group("stations"):
		sim.skilling.add_station(station.kind, station.global_position)


func register(entity: Node) -> void:
	if entity.entity_id == 0:
		entity.entity_id = _next_auto_id
		_next_auto_id += 1
	entity.register(sim)
	_entities[entity.entity_id] = entity


func entity(id: int) -> Node:
	return _entities.get(id)


## Nearest living, attackable entity to from_id within max_distance, or -1.
func nearest_target(from_id: int, max_distance: float) -> int:
	var origin: Vector3 = _entities[from_id].body().global_position
	var best_id := -1
	var best_distance := max_distance
	for id in _entities:
		var entity: Node = _entities[id]
		if id == from_id or not entity.attackable or not entity.combatant.is_alive():
			continue
		var distance := origin.distance_to(entity.body().global_position)
		if distance <= best_distance:
			best_id = id
			best_distance = distance
	return best_id


func _physics_process(delta: float) -> void:
	for i in clock.advance(delta):
		for id in _entities:
			sim.set_position(id, _entities[id].body().global_position)
		for event in sim.step():
			for entity in _entities.values():
				entity.on_sim_event(event)
			_mirror_ground(event)
			sim_event.emit(event)
		ticked.emit(sim.tick)


## Mirrors and broadcasts an event that didn't come from step(), such as
## state restored from a save.
func replay_event(event: Dictionary) -> void:
	_mirror_ground(event)
	sim_event.emit(event)


## Nearest ground pile within range of a position, or null. With an
## inventory, piles with nothing that fits are skipped.
func nearest_pile(origin: Vector3, max_distance: float, inventory: RefCounted = null) -> Node3D:
	var best: Node3D = null
	var best_distance := max_distance
	for pile in _piles.values():
		if inventory and not pile.items.any(func(e): return inventory.space_for(e["item"], e["quantity"]) > 0):
			continue
		var distance := origin.distance_to(pile.global_position)
		if distance <= best_distance:
			best = pile
			best_distance = distance
	return best


func _mirror_ground(event: Dictionary) -> void:
	match event["type"]:
		"hit":
			if event.get("ranged", false):
				_shoot(event)
		"ground_add":
			_piles[event["pile"]] = LootPile.spawn(get_parent(), event["pile"], event["position"], event["items"])
		"ground_update":
			_piles[event["pile"]].set_items(event["items"])
		"rock_depleted", "rock_respawned":
			_rocks[event["rock"]].set_depleted(event["type"] == "rock_depleted")
		"grave_add":
			_graves[event["grave"]] = GraveMarker.spawn(get_parent(), self, event["position"], event["expires_at"])
		"grave_remove":
			var marker: Node = _graves.get(event["grave"])
			if marker:
				marker.queue_free()
				_graves.erase(event["grave"])
		"ground_remove":
			var pile: Node = _piles.get(event["pile"])
			if pile:
				pile.queue_free()
				_piles.erase(event["pile"])


func _shoot(event: Dictionary) -> void:
	var attacker: Node = _entities.get(event["attacker"])
	var target: Node = _entities.get(event["target"])
	if attacker == null or target == null:
		return
	var weapon: Dictionary = attacker.combatant.equipment.weapon() if attacker.combatant.equipment else {}
	var up := Vector3(0, 0.4, 0)
	Projectile.spawn(get_parent(), attacker.body().global_position + up, target.body().global_position + up, weapon.get("ammo", "arrow"))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		var next := (tick_lengths.find(clock.tick_length) + 1) % tick_lengths.size()
		clock.tick_length = tick_lengths[next]
