extends RefCounted
## Subtle curse visuals: a puff of dark motes when a curse strikes, and a
## few motes slowly circling a cursed creature while the curse lasts.

const MOTE_COUNT := 5
const ORBIT_RADIUS := 0.45
const AURA_NAME := "CurseAura"


static func puff(parent: Node, at: Vector3) -> void:
	var puff := Node3D.new()
	parent.add_child(puff)
	puff.global_position = at
	for i in MOTE_COUNT + 2:
		var mote := _mote(0.07)
		var angle := TAU * i / (MOTE_COUNT + 2)
		puff.add_child(mote)
		var out := Vector3(cos(angle), randf_range(-0.3, 0.5), sin(angle)) * 0.5
		var tween := mote.create_tween().set_parallel()
		tween.tween_property(mote, "position", out, 0.5)
		tween.tween_property(mote, "scale", Vector3.ONE * 0.2, 0.5)
	puff.get_tree().create_timer(0.55).timeout.connect(puff.queue_free)


## Adds (or refreshes) the circling motes on a body for seconds.
static func aura(body: Node3D, seconds: float, tint: Color) -> void:
	var existing := body.get_node_or_null(AURA_NAME)
	if existing:
		existing.queue_free()
	var ring := Node3D.new()
	ring.name = AURA_NAME
	ring.position.y = 1.0
	body.add_child(ring)
	for i in MOTE_COUNT:
		var mote := _mote(0.06, tint)
		var angle := TAU * i / MOTE_COUNT
		mote.position = Vector3(cos(angle), sin(angle * 2.0) * 0.15, sin(angle)) * ORBIT_RADIUS
		ring.add_child(mote)
	var spin := ring.create_tween().set_loops()
	spin.tween_property(ring, "rotation:y", TAU, 2.5).from(0.0)
	body.get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(ring):
			ring.queue_free())


static func _mote(radius: float, tint := Color(0.08, 0.05, 0.1)) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(tint, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = tint.lightened(0.2)
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance
