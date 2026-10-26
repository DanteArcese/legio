extends StaticBody3D
## The villa grounds, far east of the fort (x around 320): a level, walled
## estate with a house and a courtyard, built at startup in the overworld's
## low-poly style. The building hotspots and the road back are scene nodes.

const X_MIN := 290.0
const X_MAX := 350.0
const Z_MIN := -30.0
const Z_MAX := 30.0
const PAD := 25.0
const CELL := 1.0

const GRASS := Color(0.42, 0.6, 0.28)
const GRASS_LIGHT := Color(0.5, 0.66, 0.32)
const COURTYARD := Color(0.72, 0.66, 0.55)
const PATH := Color(0.62, 0.5, 0.35)
const WALL := Color(0.78, 0.72, 0.6)
## The paved courtyard in front of the house.
const COURT := Rect2(305, -12, 30, 18)

var _noise := FastNoiseLite.new()


func _init() -> void:
	collision_layer = 1
	add_to_group("navigation_source")


func _ready() -> void:
	_noise.seed = 33
	_noise.frequency = 0.06
	_build_ground()
	_build_walls()


func height_at(x: float, z: float) -> float:
	var inside := x > X_MIN and x < X_MAX and z > Z_MIN and z < Z_MAX
	if inside:
		return 0.0
	var dx := maxf(maxf(X_MIN - x, x - X_MAX), 0.0)
	var dz := maxf(maxf(Z_MIN - z, z - Z_MAX), 0.0)
	return smoothstep(0.0, PAD, maxf(dx, dz)) * 7.0 + _noise.get_noise_2d(x, z) * 1.2


func color_at(x: float, z: float) -> Color:
	var p := Vector2(x, z)
	if COURT.has_point(p):
		return COURTYARD
	if absf(x - 320.0) < 1.5 and z > COURT.end.y:
		return PATH
	return GRASS.lerp(GRASS_LIGHT, _noise.get_noise_2d(x * 4.0, z * 4.0) * 0.5 + 0.5)


func _build_ground() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	for ix in int((X_MAX - X_MIN + PAD * 2.0) / CELL):
		for iz in int((Z_MAX - Z_MIN + PAD * 2.0) / CELL):
			var x0 := X_MIN - PAD + ix * CELL
			var z0 := Z_MIN - PAD + iz * CELL
			var points := []
			for c in [Vector2(x0, z0), Vector2(x0 + CELL, z0), Vector2(x0 + CELL, z0 + CELL), Vector2(x0, z0 + CELL)]:
				points.append(Vector3(c.x, height_at(c.x, c.y), c.y))
			tool.set_color(color_at(x0 + CELL * 0.5, z0 + CELL * 0.5))
			for index in [0, 1, 2, 0, 2, 3]:
				tool.add_vertex(points[index])
	tool.generate_normals()
	var mesh := tool.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = "GroundMesh"
	instance.mesh = mesh
	add_child(instance)
	var shape := CollisionShape3D.new()
	var faces := ConcavePolygonShape3D.new()
	faces.set_faces(mesh.get_faces())
	shape.shape = faces
	add_child(shape)


## A low plastered wall round the estate, with a gap for the road south.
func _build_walls() -> void:
	var height := 1.4
	var gate_half := 2.0
	var spans := [
		[Vector3((X_MIN + X_MAX) / 2.0, 0, Z_MIN), Vector3(X_MAX - X_MIN, height, 0.4)],
		[Vector3(X_MIN, 0, 0), Vector3(0.4, height, Z_MAX - Z_MIN)],
		[Vector3(X_MAX, 0, 0), Vector3(0.4, height, Z_MAX - Z_MIN)],
		[Vector3((X_MIN + 320.0 - gate_half) / 2.0, 0, Z_MAX), Vector3(320.0 - gate_half - X_MIN, height, 0.4)],
		[Vector3((X_MAX + 320.0 + gate_half) / 2.0, 0, Z_MAX), Vector3(X_MAX - 320.0 - gate_half, height, 0.4)],
	]
	for span in spans:
		var at: Vector3 = span[0]
		var size: Vector3 = span[1]
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = size
		shape.position = at + Vector3(0, size.y / 2.0, 0)
		add_child(shape)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		var material := StandardMaterial3D.new()
		material.albedo_color = WALL
		box.material = material
		mesh.mesh = box
		mesh.position = shape.position
		add_child(mesh)
