extends StaticBody3D
## Seriphos: a Greek island far over the sea from Portus Salis, built at
## startup in the overworld's low-poly style. The ferry ties up at a pier
## on the north shore; behind the beach is a white harbour town, an olive
## grove to the west, the ruined temple of Athena to the east, and rocky
## hills rising inland to the south.
##
## It lies far south of the harbour (z around 320, the same x), so the
## coast's surf ambience carries over.

const X_MIN := -360.0
const X_MAX := -240.0
const Z_MIN := 260.0
const Z_MAX := 380.0
const CELL := 1.0
const PAD := 30.0
const WATER_LEVEL := -0.35
const SEA_FLOOR := -1.8
## The shoreline runs east to west; the sea is north of it (smaller z).
const SHORE := 268.0
const BEACH_END := 276.0
const PIER_X := -300.0
const PIER_HALF_WIDTH := 1.5
const PIER_START := 274.0
const PIER_END := 252.0
const PIER_HEIGHT := 0.35
## Kept flat: the harbour town, the paths, the grove and the temple.
const TOWN := Rect2(-322, 276, 44, 22)
const PATHS := [
	[Vector2(-300, 276), Vector2(-300, 304), Vector2(-318, 322)],
	[Vector2(-300, 298), Vector2(-272, 306)],
	[Vector2(-300, 298), Vector2(-330, 300)],
]
const GROVE := Rect2(-354, 290, 24, 26)
const TEMPLE := Rect2(-276, 300, 22, 14)
const OLIVE_COUNT := 26

const GRASS := Color(0.55, 0.6, 0.32)
const GRASS_LIGHT := Color(0.63, 0.66, 0.38)
const SAND := Color(0.88, 0.82, 0.62)
const WET_SAND := Color(0.7, 0.64, 0.48)
const PATH := Color(0.78, 0.72, 0.58)
const PAVING := Color(0.85, 0.83, 0.78)
const ROCK := Color(0.66, 0.62, 0.56)
const MARBLE := Color(0.92, 0.9, 0.86)
const TIMBER := Color(0.45, 0.33, 0.22)

@export var dresser: Node

var _noise := FastNoiseLite.new()


func _init() -> void:
	collision_layer = 1
	add_to_group("navigation_source")


func _ready() -> void:
	_noise.seed = 1261
	_noise.frequency = 0.04
	_build_ground()
	_build_sea()
	_build_pier()
	_build_bounds()
	_build_temple()
	if dresser:
		_dress()


func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * 2.0
	var flat := 1.0 - smoothstep(0.0, 4.0, _rect_distance(TOWN, p))
	flat = maxf(flat, 1.0 - smoothstep(2.5, 6.0, _path_distance(p)))
	flat = maxf(flat, 1.0 - smoothstep(0.0, 3.0, _rect_distance(GROVE, p)))
	flat = maxf(flat, 1.0 - smoothstep(0.0, 3.0, _rect_distance(TEMPLE, p)))
	h = lerpf(h, 0.0, flat)
	# Rocky hills rise inland, to the south.
	h += smoothstep(330.0, 375.0, z) * (3.0 + _noise.get_noise_2d(x * 2.0, z * 2.0) * 2.0) * (1.0 - flat)
	# Hills frame the walkable edges.
	var edge := maxf(smoothstep(X_MAX - 6.0, X_MAX + PAD, x), smoothstep(X_MIN + 6.0, X_MIN - PAD, x))
	edge = maxf(edge, smoothstep(Z_MAX - 6.0, Z_MAX + PAD, z))
	h += edge * 9.0 * smoothstep(SHORE, BEACH_END + 4.0, z)
	# The beach slopes gently to the shoreline, then drops into the sea.
	h = lerpf(h, -0.1, 1.0 - smoothstep(SHORE + 1.0, BEACH_END, z))
	return lerpf(h, SEA_FLOOR, 1.0 - smoothstep(SHORE - 5.0, SHORE + 0.5, z))


func color_at(x: float, z: float, height: float) -> Color:
	var p := Vector2(x, z)
	if height < WATER_LEVEL + 0.1:
		return WET_SAND
	if z < BEACH_END + 0.5:
		return SAND
	if TOWN.grow(-2.0).has_point(p) or TEMPLE.has_point(p):
		return PAVING
	if _path_distance(p) < 1.8:
		return PATH
	if height > 3.0:
		return ROCK
	return GRASS.lerp(GRASS_LIGHT, _noise.get_noise_2d(x * 4.0, z * 4.0) * 0.5 + 0.5)


func _build_ground() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var heights := {}
	var corner := func(x: float, z: float) -> float:
		var key := Vector2i(roundi(x), roundi(z))
		if not heights.has(key):
			heights[key] = height_at(x, z)
		return heights[key]
	for ix in int((X_MAX - X_MIN + PAD * 2.0) / CELL):
		for iz in int((Z_MAX - Z_MIN + PAD) / CELL):
			var x0 := X_MIN - PAD + ix * CELL
			var z0 := Z_MIN + iz * CELL
			var points := []
			for c in [Vector2(x0, z0), Vector2(x0 + CELL, z0), Vector2(x0 + CELL, z0 + CELL), Vector2(x0, z0 + CELL)]:
				points.append(Vector3(c.x, corner.call(c.x, c.y), c.y))
			tool.set_color(color_at(x0 + CELL * 0.5, z0 + CELL * 0.5, (points[0].y + points[2].y) * 0.5))
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


func _build_sea() -> void:
	var water := MeshInstance3D.new()
	water.name = "Sea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(X_MAX - X_MIN + PAD * 2.0 + 80.0, 70.0)
	plane.subdivide_width = 40
	plane.subdivide_depth = 24
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/water.gdshader")
	plane.material = material
	water.mesh = plane
	water.position = Vector3((X_MIN + X_MAX) / 2.0, WATER_LEVEL, SHORE + 4.0 - 35.0)
	add_child(water)


## A timber pier north into the sea, railed, with a ramp up from the sand.
func _build_pier() -> void:
	var length := PIER_START - PIER_END
	var centre_z := (PIER_START + PIER_END) / 2.0
	_solid(Vector3(PIER_HALF_WIDTH * 2.0, PIER_HEIGHT + 2.0, length), Vector3(PIER_X, PIER_HEIGHT / 2.0 - 1.0, centre_z))
	_visual_box(Vector3(PIER_HALF_WIDTH * 2.0, 0.12, length), Vector3(PIER_X, PIER_HEIGHT, centre_z), TIMBER)
	for side: float in [-1.0, 1.0]:
		var x := PIER_X + side * (PIER_HALF_WIDTH + 0.05)
		var rail_length := SHORE - PIER_END
		_solid(Vector3(0.12, 1.0, rail_length), Vector3(x, PIER_HEIGHT + 0.5, (SHORE + PIER_END) / 2.0))
		_visual_box(Vector3(0.12, 1.0, rail_length), Vector3(x, PIER_HEIGHT + 0.5, (SHORE + PIER_END) / 2.0), TIMBER.darkened(0.2))
		var z := PIER_START - 1.0
		while z > PIER_END:
			_visual_box(Vector3(0.22, 2.2, 0.22), Vector3(x, PIER_HEIGHT - 0.9, z), TIMBER.darkened(0.35))
			z -= 3.0
	var run := 3.0
	var rise := PIER_HEIGHT + 0.05
	var ramp := CollisionShape3D.new()
	ramp.shape = BoxShape3D.new()
	ramp.shape.size = Vector3(PIER_HALF_WIDTH * 2.0, 0.2, sqrt(run * run + rise * rise))
	ramp.position = Vector3(PIER_X, rise / 2.0 - 0.1, PIER_START + run / 2.0)
	ramp.rotation.x = atan2(rise, run)
	add_child(ramp)
	var look := _visual_box(ramp.shape.size, ramp.position, TIMBER)
	look.rotation = ramp.rotation


## Invisible walls at the walkable edges; the shoreline wall leaves a gap
## for the pier.
func _build_bounds() -> void:
	var left := PIER_X - PIER_HALF_WIDTH - X_MIN
	var right := X_MAX - (PIER_X + PIER_HALF_WIDTH)
	_solid(Vector3(left, 4.0, 0.6), Vector3(X_MIN + left / 2.0, 1.0, SHORE))
	_solid(Vector3(right, 4.0, 0.6), Vector3(X_MAX - right / 2.0, 1.0, SHORE))
	_solid(Vector3(X_MAX - X_MIN, 8.0, 0.6), Vector3((X_MIN + X_MAX) / 2.0, 2.0, Z_MAX - 1.0))
	for x in [X_MIN + 1.0, X_MAX - 1.0]:
		_solid(Vector3(0.6, 8.0, Z_MAX - Z_MIN), Vector3(x, 2.0, (Z_MIN + Z_MAX) / 2.0))


## The ruined temple of Athena: a marble platform with a ring of columns,
## some standing, some fallen.
func _build_temple() -> void:
	var centre := TEMPLE.get_center()
	_solid(Vector3(TEMPLE.size.x - 4.0, 0.3, TEMPLE.size.y - 4.0), Vector3(centre.x, 0.0, centre.y))
	_visual_box(Vector3(TEMPLE.size.x - 4.0, 0.3, TEMPLE.size.y - 4.0), Vector3(centre.x, 0.0, centre.y), MARBLE.darkened(0.08))
	var half := Vector2(TEMPLE.size.x / 2.0 - 3.0, TEMPLE.size.y / 2.0 - 3.0)
	var i := 0
	for x in [-half.x, -half.x / 3.0, half.x / 3.0, half.x]:
		for z in [-half.y, half.y]:
			var at := Vector3(centre.x + x, 0.15, centre.y + z)
			if i % 3 == 2:
				# Fallen: a drum lying on its side.
				var drum := _cylinder(0.5, 3.2, MARBLE.darkened(0.04))
				drum.position = at + Vector3(1.2, 0.5, 0)
				drum.rotation.z = PI / 2.0
				_solid(Vector3(3.2, 1.0, 1.0), at + Vector3(1.2, 0.5, 0))
			else:
				var column := _cylinder(0.45, 5.0, MARBLE)
				column.position = at + Vector3(0, 2.5, 0)
				_solid(Vector3(1.0, 5.0, 1.0), at + Vector3(0, 2.5, 0))
			i += 1
	# A broken pediment slab on the north row of columns.
	_visual_box(Vector3(half.x * 1.4, 0.6, 1.4), Vector3(centre.x - half.x * 0.5, 5.3, centre.y - half.y), MARBLE.darkened(0.05))


## Olives in the grove, rocks on the hills, and boats at the pier.
func _dress() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4407
	for n in OLIVE_COUNT:
		var p := Vector2(rng.randf_range(GROVE.position.x + 1.5, GROVE.end.x - 1.5), rng.randf_range(GROVE.position.y + 1.5, GROVE.end.y - 1.5))
		var olive: Node3D = dresser.model("nature/tree_fat")
		olive.position = Vector3(p.x, height_at(p.x, p.y), p.y)
		olive.scale = Vector3.ONE * rng.randf_range(1.3, 1.8)
		olive.rotation.y = rng.randf() * TAU
		add_child(olive)
		var trunk := CollisionShape3D.new()
		trunk.shape = CylinderShape3D.new()
		trunk.shape.radius = 0.3
		trunk.shape.height = 2.0
		trunk.position = olive.position + Vector3(0, 1.0, 0)
		add_child(trunk)
	for n in 30:
		var p := Vector2(rng.randf_range(X_MIN + 4.0, X_MAX - 4.0), rng.randf_range(335.0, Z_MAX - 4.0))
		if _path_distance(p) < 5.0:
			continue
		var rock: Node3D = dresser.model("nature/" + ["rock_largeA", "rock_largeC", "rock_smallA", "rock_tallA"][n % 4])
		rock.position = Vector3(p.x, height_at(p.x, p.y) - 0.2, p.y)
		rock.scale = Vector3.ONE * rng.randf_range(1.5, 2.6)
		add_child(rock)
	for spec in [[Vector3(PIER_X - 3.4, 0, 258.0), 0.1], [Vector3(PIER_X + 3.2, 0, 262.0), PI + 0.2]]:
		var hull := _visual_box(Vector3(1.6, 0.6, 4.2), spec[0] + Vector3(0, WATER_LEVEL + 0.1, 0), Color(0.34, 0.45, 0.6))
		hull.rotation.y = spec[1]
		var mast := _visual_box(Vector3(0.12, 3.2, 0.12), spec[0] + Vector3(0, 1.6, 0), TIMBER)
		mast.rotation.y = spec[1]


func _solid(size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	shape.position = at
	add_child(shape)


func _visual_box(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	box.material = material
	mesh.mesh = box
	mesh.position = at
	add_child(mesh)
	return mesh


func _cylinder(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius * 1.1
	cylinder.height = height
	cylinder.radial_segments = 10
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	cylinder.material = material
	mesh.mesh = cylinder
	add_child(mesh)
	return mesh


func _path_distance(p: Vector2) -> float:
	var best := INF
	for path in PATHS:
		for i in path.size() - 1:
			best = minf(best, Geometry2D.get_closest_point_to_segment(p, path[i], path[i + 1]).distance_to(p))
	return best


static func _rect_distance(rect: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(rect.position.x - p.x, 0.0), p.x - rect.end.x)
	var dz := maxf(maxf(rect.position.y - p.y, 0.0), p.y - rect.end.y)
	return Vector2(dx, dz).length()
