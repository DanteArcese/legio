extends CharacterBody3D
## Directly controlled player: left stick / WASD moves relative to the camera.
## Interact picks up nearby loot, loots your grave, mines a rock, uses a
## crafting station, opens a bank, talks to the libitinarius or a venator,
## or targets the nearest enemy, in that order. With no stick input, the player walks into reach of
## its target automatically.

signal bank_opened
signal station_opened(station: Node)

const MoveMath := preload("res://scripts/player/move_math.gd")
const Skills := preload("res://scripts/sim/skills.gd")

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
	if direction == Vector3.ZERO:
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


## Direction toward the current target while out of reach, otherwise zero.
func _approach_direction() -> Vector3:
	var target_position: Variant = _target_position()
	if target_position == null:
		return Vector3.ZERO
	var offset: Vector3 = (target_position - global_position) * Vector3(1, 0, 1)
	if offset.length() <= _entity.combatant.reach * 0.9:
		return Vector3.ZERO
	return offset.normalized()


func _target_position() -> Variant:
	if not sim_driver or not _entity.combatant:
		return null
	var target: RefCounted = sim_driver.sim.get_combatant(_entity.combatant.target_id)
	return target.position if target else null
