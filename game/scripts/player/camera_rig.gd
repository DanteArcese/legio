extends Node3D
## Orbit camera that follows a target. Right stick / arrow keys orbit,
## middle mouse drag orbits, and wheel / D-pad zooms. Pitch reaches a high
## overhead angle for an OSRS-like view.

@export var target: Node3D
@export var stick_speed := 2.5
@export var mouse_sensitivity := 0.005
@export var min_pitch := deg_to_rad(-80.0)
@export var max_pitch := deg_to_rad(-10.0)
@export var min_distance := 3.0
@export var max_distance := 24.0
@export var zoom_step := 1.5

@onready var _arm: SpringArm3D = $SpringArm3D

var _pitch := deg_to_rad(-42.0)
var _yaw := 0.0


func _ready() -> void:
	_apply_rotation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_orbit(-event.relative.x * mouse_sensitivity, -event.relative.y * mouse_sensitivity)
	elif event.is_action_pressed("camera_zoom_in"):
		_arm.spring_length = clampf(_arm.spring_length - zoom_step, min_distance, max_distance)
	elif event.is_action_pressed("camera_zoom_out"):
		_arm.spring_length = clampf(_arm.spring_length + zoom_step, min_distance, max_distance)


func _process(delta: float) -> void:
	var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	_orbit(-look.x * stick_speed * delta, -look.y * stick_speed * delta)
	if target:
		global_position = target.global_position


func _orbit(yaw_delta: float, pitch_delta: float) -> void:
	_yaw = wrapf(_yaw + yaw_delta, -PI, PI)
	_pitch = clampf(_pitch + pitch_delta, min_pitch, max_pitch)
	_apply_rotation()


func _apply_rotation() -> void:
	rotation = Vector3(_pitch, _yaw, 0.0)
