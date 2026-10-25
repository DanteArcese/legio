extends CharacterBody3D
## Directly controlled player: left stick / WASD moves relative to the camera.
## Interact targets the nearest enemy; with no stick input, the player walks
## into reach of its target automatically.

const MoveMath := preload("res://scripts/player/move_math.gd")
const Skills := preload("res://scripts/sim/skills.gd")

@export var walk_speed := 3.0
@export var run_speed := 6.0
@export var turn_speed := 12.0
@export var target_radius := 8.0
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
		var target_id: int = sim_driver.nearest_target(_entity.entity_id, target_radius)
		if target_id == -1:
			sim_driver.sim.queue_stop(_entity.entity_id)
		else:
			sim_driver.sim.queue_attack(_entity.entity_id, target_id)


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
