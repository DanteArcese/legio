extends Node3D
## A shot flying from attacker to target: an arrow (thin rod) or a sling
## stone (small ball). Purely visual; the simulation already resolved the hit.

const FLIGHT_TIME := 0.25


static func spawn(parent: Node, from: Vector3, to: Vector3, ammo_type: String) -> void:
	var shot := new()
	var mesh := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	if ammo_type == "sling_bullet":
		var ball := SphereMesh.new()
		ball.radius = 0.07
		ball.height = 0.14
		material.albedo_color = Color(0.45, 0.45, 0.5)
		ball.material = material
		mesh.mesh = ball
	else:
		var rod := BoxMesh.new()
		rod.size = Vector3(0.04, 0.04, 0.7)
		material.albedo_color = Color(0.55, 0.4, 0.25)
		rod.material = material
		mesh.mesh = rod
	shot.add_child(mesh)
	parent.add_child(shot)
	shot.global_position = from
	if from.distance_to(to) > 0.01:
		shot.look_at(to, Vector3.UP)
	var tween := shot.create_tween()
	tween.tween_property(shot, "global_position", to, FLIGHT_TIME)
	tween.tween_callback(shot.queue_free)
