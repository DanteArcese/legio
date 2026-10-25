extends CharacterBody3D
## Directly controlled player: left stick / WASD moves relative to the camera.

const MoveMath := preload("res://scripts/player/move_math.gd")

@export var walk_speed := 3.0
@export var run_speed := 6.0
@export var turn_speed := 12.0
@export var camera_rig: Node3D

var running := true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("run_toggle"):
		running = not running


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw := camera_rig.global_rotation.y if camera_rig else 0.0
	var direction := MoveMath.camera_relative(input, yaw)
	var speed := run_speed if running else walk_speed

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

	if direction.length_squared() > 0.0001:
		var target_yaw := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(turn_speed * delta, 1.0))
