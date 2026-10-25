extends RefCounted
## Hand-held props the KayKit packs lack, built from chunky primitives in
## the same style: the hunting bow, the composite bow, and the sling.
## Oriented like KayKit's weapons: held at the origin, length along +Y,
## facing +Z.

const WOOD := Color(0.55, 0.35, 0.18)
const WOOD_DARK := Color(0.38, 0.23, 0.12)
const HORN := Color(0.86, 0.8, 0.66)
const GRIP := Color(0.25, 0.16, 0.1)
const STRING := Color(0.92, 0.88, 0.78)
const CORD := Color(0.6, 0.5, 0.36)
const STONE := Color(0.5, 0.5, 0.54)


static func build(name: String) -> Node3D:
	match name:
		"bow":
			return _bow(WOOD, WOOD_DARK, 0.25)
		"bow_composite":
			return _bow(WOOD_DARK, HORN, 0.4)
		"sling":
			return _sling()
	return Node3D.new()


## A bow bending toward +Z, string at the back. recurve curls the tips.
static func _bow(wood: Color, tips: Color, recurve: float) -> Node3D:
	var bow := Node3D.new()
	bow.name = "Bow"
	var segments := 7
	var half_length := 1.1
	var depth := 0.28
	var points: Array[Vector3] = []
	for i in range(-segments, segments + 1):
		var t := float(i) / segments
		var z := depth * (1.0 - t * t)
		# Recurve: the last stretch bends back the other way.
		if absf(t) > 0.8:
			z -= recurve * (absf(t) - 0.8) * 2.0
		points.append(Vector3(0, t * half_length, z))
	for i in points.size() - 1:
		var thick := 0.07 if absf(i - segments) < 2 else 0.05
		var color := tips if i == 0 or i == points.size() - 2 else wood
		bow.add_child(_rod(points[i], points[i + 1], thick, color))
	bow.add_child(_rod(points[segments] + Vector3(0, -0.12, 0), points[segments] + Vector3(0, 0.12, 0), 0.085, GRIP))
	bow.add_child(_rod(points[0], points[points.size() - 1], 0.015, STRING))
	return bow


## Two cords from the hand down to a pouch holding a stone.
static func _sling() -> Node3D:
	var sling := Node3D.new()
	sling.name = "Sling"
	var pouch_at := Vector3(0, -0.8, 0.1)
	sling.add_child(_rod(Vector3(-0.03, 0, 0), pouch_at + Vector3(-0.06, 0, 0), 0.03, CORD))
	sling.add_child(_rod(Vector3(0.03, 0, 0), pouch_at + Vector3(0.06, 0, 0), 0.03, CORD))
	var pouch := MeshInstance3D.new()
	var leather := SphereMesh.new()
	leather.radius = 0.1
	leather.height = 0.1
	leather.material = _material(CORD.darkened(0.3))
	pouch.mesh = leather
	pouch.position = pouch_at
	sling.add_child(pouch)
	var stone := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.06
	ball.height = 0.12
	ball.material = _material(STONE)
	stone.mesh = ball
	stone.position = pouch_at + Vector3(0, 0.03, 0)
	sling.add_child(stone)
	return sling


## A box stretched between two points.
static func _rod(a: Vector3, b: Vector3, thickness: float, color: Color) -> MeshInstance3D:
	var rod := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(thickness, a.distance_to(b) + thickness * 0.5, thickness)
	box.material = _material(color)
	rod.mesh = box
	rod.position = (a + b) / 2.0
	# Local Y runs along the rod; X and Z are any perpendicular pair.
	var y := (b - a).normalized()
	var helper := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := helper.cross(y).normalized()
	rod.basis = Basis(x, y, x.cross(y).normalized())
	return rod


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material
