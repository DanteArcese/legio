extends CharacterBody3D
## The player character.
##
## Controller / WASD: the left stick moves relative to the camera, and
## Interact picks up nearby loot, loots your grave, mines a rock, uses a
## crafting station, opens a bank, talks to the libitinarius or a venator,
## or targets the nearest enemy, in that order.
##
## Mouse: left-click the ground to walk there, a monster to attack it, or
## anything interactable to walk up and use it. Paths follow the navigation
## mesh, and so does the automatic walk into reach of a combat target.

signal bank_opened
signal station_opened(station: Node)

const MoveMath := preload("res://scripts/player/move_math.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const Navigation := preload("res://scripts/world/navigation.gd")

const CLICK_RAY_LENGTH := 300.0
## Terrain (1), monsters (4), and props (8) can be clicked.
const CLICK_MASK := 1 | 4 | 8
const INTERACTABLE_GROUPS := ["rocks", "stations", "banks", "libitinarii", "venatores"]
## How close to walk to a clicked interactable before using it.
const CLICK_USE_DISTANCE := 1.6

@export var walk_speed := 3.0
@export var run_speed := 6.0
@export var turn_speed := 12.0
@export var target_radius := 8.0
@export var pickup_radius := 2.0
@export var bank_radius := 2.5
@export var grave_radius := 1.8
@export var camera_rig: Node3D
@export var sim_driver: Node

var running := true
## Click-to-move destination, or null.
var destination: Variant = null
## Node to interact with on arrival (or a position for loot and graves).
var _pending_use: Variant = null

@onready var _entity: Node = $SimEntity


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("run_toggle"):
		running = not running
	elif event.is_action_pressed("combat_style") and sim_driver:
		var styles: Array = Skills.STYLES
		var next: String = styles[(styles.find(_entity.combatant.style) + 1) % styles.size()]
		sim_driver.sim.queue_style(_entity.entity_id, next)
	elif event.is_action_pressed("interact") and sim_driver:
		interact()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and sim_driver:
		click(event.position)


## Handles a left-click at a screen position.
func click(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var from := camera.project_ray_origin(screen_position)
	var query := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(screen_position) * CLICK_RAY_LENGTH, CLICK_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Node = hit["collider"]
	var id: int = _entity.entity_id
	var entity: Node = collider.get_node_or_null("SimEntity")
	if entity and entity.attackable and entity.combatant and entity.combatant.is_alive():
		destination = null
		_pending_use = null
		sim_driver.sim.queue_attack(id, entity.entity_id)
		return
	for group in INTERACTABLE_GROUPS:
		if collider.is_in_group(group):
			walk_to(collider.global_position, collider)
			return
	# Ground: walk there, cancelling combat and skilling. Clicking right next
	# to loot or your grave picks it up on arrival.
	sim_driver.sim.queue_stop(id)
	sim_driver.sim.queue_item_action(id, "stop_action")
	var point: Vector3 = hit["position"]
	var use: Variant = null
	for node in get_tree().get_nodes_in_group("loot_piles") + get_tree().get_nodes_in_group("graves"):
		if (node.global_position - point).length() < 1.2:
			use = node.global_position
	walk_to(point, use)


## Walks along the navigation mesh to a point; on arrival, interacts if
## use is a node or a position.
func walk_to(point: Vector3, use: Variant = null) -> void:
	destination = Navigation.closest_walkable(get_world_3d(), point) if use is Node else point
	_pending_use = use


func interact() -> void:
	var id: int = _entity.entity_id
	var pile: Node3D = sim_driver.nearest_pile(global_position, pickup_radius, _entity.combatant.inventory)
	if pile:
		sim_driver.sim.queue_item_action(id, "pickup", {"pile": pile.pile_id})
		return
	if _near_any("graves", grave_radius):
		sim_driver.sim.queue_item_action(id, "loot_grave")
		return
	var rock := _nearest_in_group("rocks", grave_radius + 0.4)
	if rock:
		sim_driver.sim.queue_item_action(id, "mine", {"rock": rock.rock_id})
		return
	var station := _nearest_in_group("stations", grave_radius + 0.4)
	if station:
		station_opened.emit(station)
		return
	if _near_any("banks", bank_radius):
		bank_opened.emit()
		return
	if _near_any("libitinarii", bank_radius):
		sim_driver.sim.queue_item_action(id, "reclaim")
		return
	for venator in get_tree().get_nodes_in_group("venatores"):
		if global_position.distance_to(venator.global_position) <= bank_radius:
			sim_driver.sim.queue_item_action(id, "slayer_task", {"venator": venator.get_meta("venator_id")})
			return
	var target_id: int = sim_driver.nearest_target(id, target_radius)
	if target_id == -1:
		sim_driver.sim.queue_stop(id)
	else:
		sim_driver.sim.queue_attack(id, target_id)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw := camera_rig.global_rotation.y if camera_rig else 0.0
	var direction := MoveMath.camera_relative(input, yaw)
	var face_target := false
	if direction != Vector3.ZERO:
		destination = null
		_pending_use = null
	elif destination != null:
		direction = _destination_direction()
	else:
		var approach := _approach_direction()
		direction = approach
		face_target = approach == Vector3.ZERO and _target_position() != null
	var speed := run_speed if running else walk_speed

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

	var facing := direction
	if face_target:
		facing = (_target_position() - global_position) * Vector3(1, 0, 1)
	if facing.length_squared() > 0.0001:
		var target_yaw := atan2(-facing.x, -facing.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(turn_speed * delta, 1.0))


func _near_any(group: String, radius: float) -> bool:
	return _nearest_in_group(group, radius) != null


func _nearest_in_group(group: String, radius: float) -> Node3D:
	var best: Node3D = null
	var best_distance := radius
	for node in get_tree().get_nodes_in_group(group):
		var offset: Vector3 = (node.global_position - global_position) * Vector3(1, 0, 1)
		if offset.length() <= best_distance:
			best = node
			best_distance = offset.length()
	return best


## Direction along the path to the click destination; arriving stops and
## uses whatever was clicked.
func _destination_direction() -> Vector3:
	var arrive_distance := 0.3
	var use_position: Variant = null
	if _pending_use is Node:
		use_position = _pending_use.global_position
		arrive_distance = CLICK_USE_DISTANCE
	elif _pending_use is Vector3:
		use_position = _pending_use
		arrive_distance = 0.8
	var goal: Vector3 = use_position if use_position != null else destination
	if _flat(goal - global_position).length() <= arrive_distance or _flat(destination - global_position).length() <= 0.3:
		var use: Variant = _pending_use
		destination = null
		_pending_use = null
		if use != null:
			interact()
		return Vector3.ZERO
	return _flat(Navigation.next_waypoint(get_world_3d(), global_position, destination) - global_position).normalized()


## Direction along the path toward the current target while out of reach,
## otherwise zero.
func _approach_direction() -> Vector3:
	var target_position: Variant = _target_position()
	if target_position == null:
		return Vector3.ZERO
	if _flat(target_position - global_position).length() <= _entity.combatant.reach * 0.9:
		return Vector3.ZERO
	return _flat(Navigation.next_waypoint(get_world_3d(), global_position, target_position) - global_position).normalized()


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _target_position() -> Variant:
	if not sim_driver or not _entity.combatant:
		return null
	var target: RefCounted = sim_driver.sim.get_combatant(_entity.combatant.target_id)
	return target.position if target else null
