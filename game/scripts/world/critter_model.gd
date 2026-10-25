extends Node3D
## Animals built in code to match the KayKit characters' chunky, rounded
## style: soft capsule and sphere shapes, big heads, stubby legs, and big
## eyes. Kinds come from content "appearance": quadruped (rat, wolf, boar)
## and bird (strix), with optional features (ears, round_ears, long_snout,
## tusks, bristles, tail, ear_tufts).
##
## Same API as KaykitCharacter: create(), animate(delta, speed), attack(),
## hurt(), die(), revive(), set_work().

const STEP_RATE := 11.0
const LEG_SWING := 0.7
const WING_FLAP_RATE := 9.0
const LUNGE_TIME := 0.35
const HURT_TIME := 0.25
const DEATH_TIME := 0.6
const EYE_WHITE := Color(0.97, 0.97, 0.95)
const PUPIL := Color(0.08, 0.06, 0.06)
const NOSE := Color(0.25, 0.15, 0.15)
const PINK := Color(0.93, 0.6, 0.62)

var kind := "quadruped"
var _rig: Node3D
var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _legs: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _phase := 0.0
var _dead := false
var _busy := false
var _materials: Array[StandardMaterial3D] = []


static func create(appearance: Dictionary) -> Node3D:
	var critter := new()
	critter.kind = appearance.get("model", "quadruped")
	var main := Color.html(appearance["color"])
	var accent := Color.html(appearance.get("accent", appearance["color"]))
	var features: Array = appearance.get("features", [])
	critter._rig = Node3D.new()
	critter.add_child(critter._rig)
	if critter.kind == "bird":
		critter._build_bird(main, accent, features)
	else:
		critter._build_quadruped(main, accent, features)
	critter.scale = Vector3.ONE * float(appearance["size"])
	return critter


func animate(delta: float, speed: float) -> void:
	if _dead:
		return
	var moving := speed > 0.1
	_phase += delta * (STEP_RATE if moving else 2.2)
	var swing := sin(_phase) * LEG_SWING if moving else 0.0
	for i in _legs.size():
		# Diagonal pairs move together, like a trot.
		var sign := 1.0 if i == 0 or i == 3 else -1.0
		_legs[i].rotation.x = swing * sign
	for i in _wings.size():
		var flap := sin(_phase * WING_FLAP_RATE / STEP_RATE) * (0.8 if moving else 0.2)
		_wings[i].rotation.z = flap * (1.0 if i == 0 else -1.0)
	if _busy:
		return
	var bob := absf(sin(_phase)) * 0.05 if moving else sin(_phase) * 0.02
	_body.position.y = _body.get_meta("rest_y") + bob
	if _tail:
		_tail.rotation.y = sin(_phase * 1.3) * (0.4 if moving else 0.2)
	if _head:
		_head.rotation.x = sin(_phase * 0.5) * 0.05


## A quick lunge forward with the head snapping down.
func attack(_style := "") -> void:
	if _dead:
		return
	_busy = true
	var tween := create_tween()
	tween.tween_property(_rig, "position:z", 0.35, LUNGE_TIME * 0.4).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_head, "rotation:x", 0.5, LUNGE_TIME * 0.4)
	tween.tween_property(_rig, "position:z", 0.0, LUNGE_TIME * 0.6)
	tween.parallel().tween_property(_head, "rotation:x", 0.0, LUNGE_TIME * 0.6)
	tween.tween_callback(func(): _busy = false)


## A flinch back with a brief red flash.
func hurt() -> void:
	if _dead:
		return
	var tween := create_tween()
	tween.tween_property(_rig, "position:z", -0.15, HURT_TIME * 0.4)
	tween.tween_property(_rig, "position:z", 0.0, HURT_TIME * 0.6)
	for material in _materials:
		material.emission_enabled = true
		material.emission = Color(0.6, 0.05, 0.05)
	get_tree().create_timer(HURT_TIME).timeout.connect(func():
		for material in _materials:
			material.emission_enabled = false)


## Topples onto its side.
func die() -> void:
	_dead = true
	var tween := create_tween()
	tween.tween_property(_rig, "rotation:z", PI / 2.0, DEATH_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_rig, "position:y", -0.1, DEATH_TIME)


func revive() -> void:
	_dead = false
	_busy = false
	_rig.rotation = Vector3.ZERO
	_rig.position = Vector3.ZERO


func is_dead() -> bool:
	return _dead


func set_work(_action: String) -> void:
	pass


# --- Builders --------------------------------------------------------------

func _build_quadruped(main: Color, accent: Color, features: Array) -> void:
	var belly := main.lightened(0.25)
	_body = _part(_rig, _capsule(0.28, 0.95, main, true), Vector3(0, 0.48, 0))
	_part(_body, _capsule(0.22, 0.7, belly, true), Vector3(0, -0.08, 0))
	if features.has("bristles"):
		_part(_body, _capsule(0.08, 0.75, accent, true), Vector3(0, 0.25, 0))
	# A big head, KayKit style.
	_head = _part(_body, _sphere(0.27, main), Vector3(0, 0.18, -0.52))
	var snout_length := 0.32 if features.has("long_snout") else 0.16
	var snout := _part(_head, _capsule(0.11, snout_length + 0.12, main.lightened(0.1), true), Vector3(0, -0.07, -0.22 - snout_length / 2.0))
	if features.has("tusks"):
		# A boar's flat pink snout disc, with tusks either side.
		_part(snout, _cylinder(0.1, 0.05, PINK), Vector3(0, 0, -snout_length / 2.0 - 0.08), Vector3(PI / 2.0, 0, 0))
		for side in [-1, 1]:
			_part(_head, _cone(0.035, 0.18, Color(0.96, 0.92, 0.82)), Vector3(side * 0.12, -0.12, -0.3), Vector3(-0.6, 0, side * 0.3))
	else:
		_part(snout, _sphere(0.05, NOSE), Vector3(0, 0.03, -snout_length / 2.0 - 0.06))
	_add_eyes(_head, 0.27, 0.075)
	if features.has("ears"):
		for side in [-1, 1]:
			_part(_head, _cone(0.08, 0.22, main.darkened(0.15)), Vector3(side * 0.14, 0.24, 0.02), Vector3(0, 0, side * -0.2))
	if features.has("round_ears"):
		for side in [-1, 1]:
			var ear := _part(_head, _cylinder(0.11, 0.04, main), Vector3(side * 0.18, 0.2, 0.04), Vector3(0, 0, side * 0.5))
			_part(ear, _cylinder(0.075, 0.045, PINK), Vector3(0, 0.005, 0))
	if features.has("tail"):
		_tail = Node3D.new()
		_tail.position = Vector3(0, 0.05, 0.45)
		_body.add_child(_tail)
		var thin := features.has("round_ears") # rats get a long pink tail
		var tail_mesh := _capsule(0.035 if thin else 0.09, 0.6 if thin else 0.45, PINK if thin else main.darkened(0.1), true)
		_part(_tail, tail_mesh, Vector3(0, 0.05, 0.25), Vector3(0.35, 0, 0))
	for i in 4:
		var hip := Node3D.new()
		hip.position = Vector3(0.16 if i % 2 == 0 else -0.16, 0.36, -0.3 if i < 2 else 0.3)
		_rig.add_child(hip)
		_part(hip, _capsule(0.08, 0.36, main.darkened(0.08), false), Vector3(0, -0.15, 0))
		_part(hip, _sphere(0.085, main.darkened(0.25)), Vector3(0, -0.33, -0.02))
		_legs.append(hip)


func _build_bird(main: Color, accent: Color, features: Array) -> void:
	_body = _part(_rig, _sphere(0.36, main), Vector3(0, 0.62, 0))
	_body.scale = Vector3(1.0, 1.15, 0.95)
	_part(_body, _sphere(0.26, main.lightened(0.2)), Vector3(0, -0.05, -0.16))
	_head = _part(_body, _sphere(0.3, main), Vector3(0, 0.42, -0.03))
	# Huge glowing eyes: the strix hunts at night.
	for side in [-1, 1]:
		var disc := _part(_head, _cylinder(0.12, 0.04, accent.lightened(0.3)), Vector3(side * 0.12, 0.02, -0.24), Vector3(PI / 2.0, 0, 0))
		var eye := _part(disc, _sphere(0.075, Color(1.0, 0.75, 0.15)), Vector3(0, -0.025, 0))
		var glow := eye.mesh.material as StandardMaterial3D
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.6, 0.1)
		glow.emission_energy_multiplier = 1.5
		_part(eye, _sphere(0.035, PUPIL), Vector3(0, -0.055, 0))
	_part(_head, _cone(0.05, 0.13, Color(0.85, 0.7, 0.3)), Vector3(0, -0.08, -0.29), Vector3(-PI / 2.0 - 0.3, 0, 0))
	if features.has("ear_tufts"):
		for side in [-1, 1]:
			_part(_head, _cone(0.07, 0.22, accent), Vector3(side * 0.17, 0.27, 0), Vector3(0, 0, side * -0.35))
	for side in [-1, 1]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.3, 0.78, 0.02)
		_rig.add_child(shoulder)
		# Folded against the body, hanging down and slightly out.
		var wing := _part(shoulder, _capsule(0.13, 0.62, accent, false), Vector3(side * 0.06, -0.2, 0.05), Vector3(0, 0, side * 0.25))
		wing.scale = Vector3(0.55, 1.0, 1.0)
		_wings.append(shoulder)
	for side in [-1, 1]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.13, 0.34, 0.02)
		_rig.add_child(hip)
		_part(hip, _capsule(0.04, 0.3, Color(0.85, 0.7, 0.3), false), Vector3(0, -0.14, 0))
		_part(hip, _sphere(0.06, Color(0.25, 0.2, 0.15)), Vector3(0, -0.3, -0.04))
		_legs.append(hip)


func _add_eyes(head: Node3D, head_radius: float, eye_radius: float) -> void:
	for side in [-1, 1]:
		var eye := _part(head, _sphere(eye_radius, EYE_WHITE), Vector3(side * head_radius * 0.45, head_radius * 0.25, -head_radius * 0.8))
		_part(eye, _sphere(eye_radius * 0.55, PUPIL), Vector3(0, 0, -eye_radius * 0.6))


# --- Meshes ----------------------------------------------------------------

func _part(parent: Node3D, mesh: Mesh, at: Vector3, rotation_rad := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.rotation = rotation_rad
	instance.set_meta("rest_y", at.y)
	parent.add_child(instance)
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	_materials.append(material)
	return material


func _sphere(radius: float, color: Color) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = _material(color)
	return mesh


## A capsule lying along Z when horizontal, else standing along Y.
func _capsule(radius: float, length: float, color: Color, horizontal: bool) -> Mesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(length, radius * 2.0)
	mesh.radial_segments = 14
	mesh.rings = 6
	mesh.material = _material(color)
	if not horizontal:
		return mesh
	# Bake the rotation in so callers can treat it as lying along Z.
	var tool := SurfaceTool.new()
	tool.create_from(mesh, 0)
	var rotated := tool.commit()
	var lying := ArrayMesh.new()
	var arrays := rotated.surface_get_arrays(0)
	var turn := Basis(Vector3.RIGHT, PI / 2.0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in vertices.size():
		vertices[i] = turn * vertices[i]
		normals[i] = turn * normals[i]
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	lying.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	lying.surface_set_material(0, mesh.material)
	return lying


func _cylinder(radius: float, height: float, color: Color) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	mesh.material = _material(color)
	return mesh


func _cone(radius: float, height: float, color: Color) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.material = _material(color)
	return mesh
