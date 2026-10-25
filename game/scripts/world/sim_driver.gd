extends Node
## Runs the simulation on game ticks and relays its events to the scene.
## Press F3 to cycle tick lengths while prototyping (#4).

const Simulation := preload("res://scripts/sim/simulation.gd")
const TickClock := preload("res://scripts/sim/tick_clock.gd")
const LootPile := preload("res://scripts/world/loot_pile.gd")

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


func _ready() -> void:
	sim = Simulation.new(seed_value)
	clock.tick_length = tick_lengths[0]
	for entity in get_tree().get_nodes_in_group("sim_entities"):
		register(entity)


func register(entity: Node) -> void:
	if entity.entity_id == 0:
		entity.entity_id = _next_auto_id
		_next_auto_id += 1
	entity.register(sim)
	_entities[entity.entity_id] = entity


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
			if event["type"] == "drop":
				LootPile.spawn(get_parent(), event["position"], event["items"])
			sim_event.emit(event)
		ticked.emit(sim.tick)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		var next := (tick_lengths.find(clock.tick_length) + 1) % tick_lengths.size()
		clock.tick_length = tick_lengths[next]
