extends RefCounted
## A two-horse racing chariot (a biga) in the low-poly style: a light car
## on two wheels, a pole, and a pair of horses ahead of it. It faces -Z,
## like every character; the driver stands in the car at the origin.

const WOOD := Color(0.5, 0.36, 0.22)
const WHEEL := Color(0.32, 0.24, 0.16)
const HORSE := Color(0.46, 0.32, 0.22)
const HORSE_DARK := Color(0.3, 0.22, 0.16)
const MANE := Color(0.16, 0.12, 0.1)


## color: the faction's colour, on the car's front and the horses' plumes.
static func build(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Chariot"
	# The car: a floor, a curved front screen, and low sides.
	_box(root, Vector3(1.0, 0.08, 0.8), Vector3(0, 0.45, 0), WOOD)
	_box(root, Vector3(1.0, 0.7, 0.08), Vector3(0, 0.8, -0.4), color)
	for x in [-0.5, 0.5]:
		_box(root, Vector3(0.06, 0.4, 0.8), Vector3(x, 0.65, 0), WOOD)
		var wheel := _cylinder(root, 0.42, 0.08, Vector3(x * 1.22, 0.42, 0.1), WHEEL)
		wheel.rotation.z = PI / 2.0
		_cylinder(root, 0.08, 0.12, Vector3(x * 1.22, 0.42, 0.1), WOOD).rotation.z = PI / 2.0
	_box(root, Vector3(1.5, 0.06, 0.06), Vector3(0, 0.42, 0.1), WOOD)
	# The pole and yoke out to the horses.
	_box(root, Vector3(0.08, 0.08, 1.9), Vector3(0, 0.55, -1.35), WOOD)
	_box(root, Vector3(1.4, 0.08, 0.1), Vector3(0, 0.95, -2.2), WOOD)
	for x in [-0.42, 0.42]:
		_horse(root, Vector3(x, 0, -2.5), color, 0 if x < 0.0 else 1)
	return root


static func _horse(root: Node3D, at: Vector3, plume: Color, tint: int) -> void:
	var coat := HORSE if tint == 0 else HORSE_DARK
	_box(root, Vector3(0.36, 0.42, 1.2), at + Vector3(0, 0.95, 0), coat)
	var neck := _box(root, Vector3(0.24, 0.6, 0.28), at + Vector3(0, 1.32, -0.62), coat)
	neck.rotation.x = -0.5
	_box(root, Vector3(0.2, 0.22, 0.48), at + Vector3(0, 1.6, -0.88), coat)
	_box(root, Vector3(0.06, 0.4, 0.42), at + Vector3(0, 1.4, -0.6), MANE)
	_box(root, Vector3(0.08, 0.22, 0.08), at + Vector3(0, 1.82, -0.78), plume)
	for x in [-0.12, 0.12]:
		for z in [-0.45, 0.45]:
			_box(root, Vector3(0.09, 0.78, 0.09), at + Vector3(x, 0.39, z), coat.darkened(0.15))


static func _box(root: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = _material(color)
	mesh.mesh = box
	mesh.position = at
	root.add_child(mesh)
	return mesh


static func _cylinder(root: Node3D, radius: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 12
	cylinder.material = _material(color)
	mesh.mesh = cylinder
	mesh.position = at
	root.add_child(mesh)
	return mesh


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
