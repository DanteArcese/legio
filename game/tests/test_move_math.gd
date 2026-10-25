extends "res://tests/test_case.gd"

const MoveMath := preload("res://scripts/player/move_math.gd")


func test_forward_with_unrotated_camera_moves_toward_negative_z() -> void:
	check_near(MoveMath.camera_relative(Vector2(0, -1), 0.0), Vector3(0, 0, -1), "forward")


func test_forward_follows_camera_yaw() -> void:
	# Camera turned 90 degrees left: forward should point toward -X.
	check_near(MoveMath.camera_relative(Vector2(0, -1), PI / 2), Vector3(-1, 0, 0), "forward at yaw 90")


func test_diagonal_input_is_not_faster() -> void:
	var direction := MoveMath.camera_relative(Vector2(1, -1), 0.0)
	check(is_equal_approx(direction.length(), 1.0), "diagonal length %s" % direction.length())


func test_partial_stick_input_keeps_magnitude() -> void:
	var direction := MoveMath.camera_relative(Vector2(0, -0.5), 0.0)
	check(is_equal_approx(direction.length(), 0.5), "half-tilt length %s" % direction.length())


func test_no_input_means_no_movement() -> void:
	check_near(MoveMath.camera_relative(Vector2.ZERO, 1.2), Vector3.ZERO, "zero input")
