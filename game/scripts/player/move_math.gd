extends RefCounted
## Pure movement helpers, kept free of scene nodes so they can be unit tested.


## Converts a 2D input vector (x = right, y = back, as from Input.get_vector)
## into a world-space direction on the ground plane, relative to camera yaw.
static func camera_relative(input: Vector2, camera_yaw: float) -> Vector3:
	if input.length_squared() > 1.0:
		input = input.normalized()
	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, camera_yaw)
