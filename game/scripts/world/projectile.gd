extends Node3D
## A shot flying from attacker to target: an arrow (thin rod), a javelin
## (a long shaft with an iron head), or a sling stone (small ball). Purely
## visual; the simulation already resolved the hit.

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
	elif ammo_type == "javelin":
		var shaft := BoxMesh.new()
		shaft.size = Vector3(0.05, 0.05, 1.4)
		material.albedo_color = Color(0.5, 0.36, 0.22)
		shaft.material = material
		mesh.mesh = shaft
		var head := MeshInstance3D.new()
		var tip := BoxMesh.new()
		tip.size = Vector3(0.07, 0.07, 0.25)
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color(0.7, 0.7, 0.72)
		metal.metallic = 0.6
		tip.material = metal
		head.mesh = tip
		# look_at points -Z at the target, so the head leads.
		head.position.z = -0.8
		mesh.add_child(head)
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
