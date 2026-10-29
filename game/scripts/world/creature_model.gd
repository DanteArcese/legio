extends Node3D
## Low-poly creature built from primitives, so each monster has a readable
## silhouette without imported art. Driven by a monster's content
## "appearance": a model kind (quadruped, humanoid, bird), colours, size, and
## optional features. Animates a simple walk cycle while moving.

const LEG_SWING := 0.6
const STEP_RATE := 9.0
const WING_RATE := 7.0

var kind := "quadruped"
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _body: Node3D
var _phase := 0.0


## Builds the model. Height of the result is roughly 2 * size for humanoids
## and 1 * size for quadrupeds, with the origin at the feet.
static func create(appearance: Dictionary) -> Node3D:
	var model := new()
	model.kind = appearance.get("model", "quadruped")
	var main := Color.html(appearance["color"])
	var accent := Color.html(appearance.get("accent", appearance["color"]))
	var features: Array = appearance.get("features", [])
	match model.kind:
		"humanoid":
			model._build_humanoid(main, accent, features)
		"bird":
			model._build_bird(main, accent, features)
		_:
			model._build_quadruped(main, accent, features)
	model.scale = Vector3.ONE * float(appearance["size"])
	return model


## speed: horizontal speed in m/s, used to drive the walk cycle.
func animate(delta: float, speed: float) -> void:
	var moving := speed > 0.1
	_phase += delta * (STEP_RATE if moving else 2.0)
	var swing := sin(_phase) * LEG_SWING if moving else 0.0
	for i in _legs.size():
		_legs[i].rotation.x = swing * (1.0 if i % 2 == 0 else -1.0) * (-1.0 if i >= 2 else 1.0)
	for i in _arms.size():
		_arms[i].rotation.x = -swing * (1.0 if i == 0 else -1.0) * 0.8
	for i in _wings.size():
		var flap := sin(_phase * WING_RATE / STEP_RATE) * (0.7 if moving else 0.25)
		_wings[i].rotation.z = flap * (1.0 if i == 0 else -1.0)
	if _body:
		_body.position.y = _body.get_meta("rest_y") + (absf(sin(_phase)) * 0.04 if moving else sin(_phase) * 0.015)


func _build_quadruped(main: Color, accent: Color, features: Array) -> void:
	_body = _part(self, _box(Vector3(0.5, 0.4, 0.95), main), Vector3(0, 0.55, 0))
	if features.has("human_torso"):
		_build_rider_torso(accent)
	var head := _part(_body, _box(Vector3(0.36, 0.34, 0.4), main), Vector3(0, 0.12, -0.6))
	# A centaur's front is a man, not a horse's neck and head.
	head.visible = not features.has("human_torso")
	var snout_length := 0.32 if features.has("long_snout") else 0.18
	_part(head, _box(Vector3(0.2, 0.18, snout_length), accent), Vector3(0, -0.06, -0.2 - snout_length / 2.0))
	if features.has("ears"):
		for side in [-1, 1]:
			_part(head, _cone(0.07, 0.18, main), Vector3(side * 0.12, 0.24, 0.05))
	if features.has("round_ears"):
		for side in [-1, 1]:
			_part(head, _sphere(0.08, accent), Vector3(side * 0.15, 0.18, 0.08))
	if features.has("tusks"):
		for side in [-1, 1]:
			var tusk := _part(head, _cone(0.035, 0.18, Color(0.95, 0.92, 0.82)), Vector3(side * 0.11, -0.08, -0.38))
			tusk.rotation.x = -0.9
	if features.has("bristles"):
		_part(_body, _box(Vector3(0.12, 0.12, 0.8), accent), Vector3(0, 0.24, 0))
	if features.has("tail"):
		var tail := _part(_body, _box(Vector3(0.08, 0.08, 0.5), accent), Vector3(0, 0.08, 0.68))
		tail.rotation.x = 0.5
	for i in 4:
		var x := 0.16 if i % 2 == 0 else -0.16
		var z := -0.32 if i < 2 else 0.32
		var hip := Node3D.new()
		hip.position = Vector3(x, 0.4, z)
		add_child(hip)
		_part(hip, _box(Vector3(0.12, 0.4, 0.12), accent), Vector3(0, -0.2, 0))
		_legs.append(hip)


func _build_humanoid(main: Color, accent: Color, features: Array) -> void:
	var skin := Color(0.78, 0.6, 0.45) if not features.has("ghostly") else main.lightened(0.2)
	if features.has("green_skin"):
		skin = Color(0.48, 0.6, 0.42)
	_body = _part(self, _box(Vector3(0.5, 0.6, 0.28), main), Vector3(0, 1.15, 0))
	var head := _part(_body, _sphere(0.17, skin), Vector3(0, 0.48, 0))
	if features.has("hood"):
		_part(head, _sphere(0.2, accent), Vector3(0, 0.04, 0.03))
	if features.has("helmet"):
		_part(head, _sphere(0.19, accent), Vector3(0, 0.07, 0))
		_part(head, _box(Vector3(0.05, 0.12, 0.3), Color(0.7, 0.15, 0.1)), Vector3(0, 0.26, 0))
	if features.has("one_eye"):
		# A cyclops: one great eye in the middle of the brow.
		var white := _part(head, _sphere(0.07, Color(0.95, 0.93, 0.88)), Vector3(0, 0.04, -0.14))
		_part(white, _sphere(0.035, Color(0.15, 0.1, 0.08)), Vector3(0, 0, -0.05))
	if features.has("snakes"):
		# A gorgon: a writhing crown of serpents for hair.
		for i in 10:
			var angle := TAU * i / 10.0
			var snake := _part(head, _cone(0.025, 0.24, Color(0.25, 0.42, 0.2)), Vector3(cos(angle) * 0.14, 0.12, sin(angle) * 0.14))
			snake.rotation = Vector3(sin(angle) * 0.9, 0, -cos(angle) * 0.9)
	if features.has("glowing_eyes"):
		for side in [-1, 1]:
			var eye := _part(head, _sphere(0.035, Color(0.6, 0.9, 1.0)), Vector3(side * 0.06, 0.02, -0.15))
			(eye.mesh.material as StandardMaterial3D).emission_enabled = true
			(eye.mesh.material as StandardMaterial3D).emission = Color(0.5, 0.9, 1.0)
	_part(_body, _box(Vector3(0.54, 0.36, 0.32), accent), Vector3(0, -0.42, 0))
	if features.has("serpent_tail"):
		_build_serpent_tail(main)
	for side in [-1, 1]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.33, 1.4, 0)
		add_child(shoulder)
		_part(shoulder, _box(Vector3(0.14, 0.55, 0.14), main), Vector3(0, -0.27, 0))
		_arms.append(shoulder)
		if features.has("serpent_tail"):
			continue
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.13, 0.75, 0)
		add_child(hip)
		_part(hip, _box(Vector3(0.17, 0.75, 0.17), skin if features.has("bare_legs") else accent), Vector3(0, -0.375, 0))
		_legs.append(hip)
	if features.has("ghostly"):
		_make_translucent(self, 0.55)


## A lamia: below the waist, a serpent's body that coils back along the
## ground, thinning to the tip.
func _build_serpent_tail(scales: Color) -> void:
	var segments := 7
	for i in segments:
		var t := float(i) / segments
		var radius := lerpf(0.2, 0.05, t)
		var at := Vector3(sin(t * PI * 1.5) * 0.25, lerpf(0.75, 0.12, minf(t * 2.0, 1.0)), t * 1.1)
		_part(self, _sphere(radius, scales.darkened(0.1 * (i % 2))), at)


## A centaur: a man's torso, head and arms rising from the front of the
## horse, with a bow in the left hand.
func _build_rider_torso(skin_tone: Color) -> void:
	var skin := Color(0.76, 0.58, 0.43)
	var torso := _part(_body, _box(Vector3(0.36, 0.5, 0.24), skin), Vector3(0, 0.42, -0.36))
	_part(torso, _sphere(0.14, skin), Vector3(0, 0.38, 0))
	_part(torso, _sphere(0.15, skin_tone), Vector3(0, 0.44, 0.03))
	for side in [-1, 1]:
		var arm := _part(torso, _box(Vector3(0.1, 0.42, 0.1), skin), Vector3(side * 0.24, 0.02, -0.08))
		arm.rotation.x = -0.6
	var bow := _part(torso, _box(Vector3(0.04, 0.7, 0.04), Color(0.4, 0.27, 0.15)), Vector3(-0.3, 0.05, -0.3))
	bow.rotation.z = 0.15


func _build_bird(main: Color, accent: Color, features: Array) -> void:
	_body = _part(self, _sphere(0.32, main), Vector3(0, 0.75, 0))
	_body.scale = Vector3(1.0, 1.25, 1.0)
	var head := _part(_body, _sphere(0.22, main), Vector3(0, 0.36, -0.05))
	for side in [-1, 1]:
		var eye := _part(head, _sphere(0.06, Color(1.0, 0.8, 0.2)), Vector3(side * 0.09, 0.03, -0.17))
		(eye.mesh.material as StandardMaterial3D).emission_enabled = true
		(eye.mesh.material as StandardMaterial3D).emission = Color(1.0, 0.7, 0.1)
	var beak := _part(head, _cone(0.05, 0.12, accent), Vector3(0, -0.06, -0.22))
	beak.rotation.x = -PI / 2
	if features.has("ear_tufts"):
		for side in [-1, 1]:
			_part(head, _cone(0.05, 0.16, accent), Vector3(side * 0.12, 0.2, 0))
	for side in [-1, 1]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.28, 0.9, 0)
		add_child(shoulder)
		_part(shoulder, _box(Vector3(0.7, 0.06, 0.4), accent), Vector3(side * 0.35, 0, 0.05))
		_wings.append(shoulder)
	for side in [-1, 1]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.1, 0.42, 0)
		add_child(hip)
		_part(hip, _box(Vector3(0.06, 0.42, 0.06), Color(0.85, 0.7, 0.3)), Vector3(0, -0.21, 0))
		_legs.append(hip)


func _part(parent: Node3D, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	if parent == _body or parent == self:
		instance.set_meta("rest_y", at.y)
	parent.add_child(instance)
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


func _box(size: Vector3, color: Color) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	return mesh


func _sphere(radius: float, color: Color) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = _material(color)
	return mesh


func _cone(radius: float, height: float, color: Color) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.material = _material(color)
	return mesh


func _make_translucent(node: Node, alpha: float) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var material := child.mesh.material as StandardMaterial3D
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a = alpha
		_make_translucent(child, alpha)
