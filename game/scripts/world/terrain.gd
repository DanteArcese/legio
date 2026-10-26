extends StaticBody3D
## The overworld ground: flat-shaded, vertex-coloured low-poly terrain in
## the OSRS style, with grass tufts and a pond.
##
## Height comes from smooth noise, rising into hills toward the world edge,
## and is flattened inside the fort, along paths, and around everything you
## interact with (rocks, stations, NPCs, doorways), so gameplay stays level.
## Scenery under snap_roots is lifted onto the ground.

const ContentDB := preload("res://scripts/content/content_db.gd")
const GrassShader := preload("res://shaders/grass.gdshader")
const WaterShader := preload("res://shaders/water.gdshader")

const HALF_SIZE := 80.0
const CELL := 1.0
const HILL_HEIGHT := 3.0
const EDGE_RISE := 9.0
const FORT_HALF := 24.0
## Paths as 2D polylines (x, z), painted as dirt and kept level.
const PATHS := [
	[Vector2(0, -20), Vector2(0, -2)], [Vector2(0, 2), Vector2(0, 20)], [Vector2(2, 0), Vector2(27, -1)],
	[Vector2(0, -20), Vector2(0, -44)], [Vector2(0, 20), Vector2(0, 28)],
	[Vector2(4, 22.5), Vector2(-16, 22.5), Vector2(-16, 50)],
	[Vector2(0, -22), Vector2(-20, -30), Vector2(-45, -37)],
]
const PATH_HALF_WIDTH := 1.6
const QUARRY := Rect2(25, -6.5, 10, 8)
const FIELDS := [Rect2(2, 30, 8, 6), Rect2(-10, 34, 8, 6), Rect2(4, 38, 8, 6), Rect2(-12, 27, 8, 6)]
const FORUM := Vector2(0, -5)
const POND := Vector2(21, 37)
const POND_RADIUS := 4.5
const POND_DEPTH := 1.4
const WATER_LEVEL := -0.35
const BARROW := Vector2(-45, -45)
## Groups whose members get level ground around them.
const LEVEL_GROUPS := ["rocks", "trees", "hunt_spots", "obstacles", "obstacle_ends", "stations", "transitions", "banks", "libitinarii", "venatores", "shopkeepers", "altars"]
const LEVEL_RADIUS := 3.5

const GRASS := Color(0.37, 0.56, 0.23)
const GRASS_LIGHT := Color(0.47, 0.62, 0.27)
const HILL_GRASS := Color(0.32, 0.47, 0.24)
const DIRT := Color(0.6, 0.48, 0.33)
const STONE := Color(0.64, 0.61, 0.55)
const QUARRY_GROUND := Color(0.55, 0.52, 0.47)
const FIELD := Color(0.78, 0.68, 0.36)
const SAND := Color(0.8, 0.74, 0.55)
const POND_BED := Color(0.33, 0.38, 0.3)

## How many grass tufts each graphics preset gets.
const GRASS_COUNT := {"low": 0, "medium": 6000, "high": 14000}

@export var snap_roots: Array[NodePath] = []
@export var graphics_settings: Node

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _level_points: Array[Vector2] = []
var _grass: MultiMeshInstance3D
var _heights := {}


func _init() -> void:
	_noise.seed = 11
	_noise.frequency = 0.022
	_noise.fractal_octaves = 3
	_detail.seed = 5
	_detail.frequency = 0.15


func _ready() -> void:
	for group in LEVEL_GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node3D and absf(node.global_position.x) < HALF_SIZE:
				_level_points.append(Vector2(node.global_position.x, node.global_position.z))
	_build_ground()
	_heights.clear()
	_build_pond()
	_build_grass()
	for path in snap_roots:
		var root := get_node_or_null(path)
		if root:
			for child in root.get_children():
				if child is Node3D:
					child.global_position.y += height_at(child.global_position.x, child.global_position.z)
	if graphics_settings:
		graphics_settings.changed.connect(_on_graphics_changed)
		_on_graphics_changed()


func _height_cached(corner: Vector2) -> float:
	if not _heights.has(corner):
		_heights[corner] = height_at(corner.x, corner.y)
	return _heights[corner]


## Ground height at a world position.
func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var hills := (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * HILL_HEIGHT
	var edge := smoothstep(50.0, 72.0, maxf(absf(x), absf(z))) * EDGE_RISE
	var height := hills + edge
	var level := level_weight(p)
	height = lerpf(height, 0.0, level)
	var to_pond := p.distance_to(POND)
	if to_pond < POND_RADIUS + 2.0:
		height = lerpf(-POND_DEPTH, height, smoothstep(POND_RADIUS - 1.5, POND_RADIUS + 2.0, to_pond))
	return height


## 1 where the ground must be level (fort, paths, fields, gameplay spots).
func level_weight(p: Vector2) -> float:
	var weight := 1.0 - smoothstep(FORT_HALF, FORT_HALF + 6.0, maxf(absf(p.x), absf(p.y)))
	weight = maxf(weight, 1.0 - smoothstep(PATH_HALF_WIDTH + 1.0, PATH_HALF_WIDTH + 4.0, _path_distance(p)))
	weight = maxf(weight, 1.0 - smoothstep(0.0, 4.0, _rect_distance(QUARRY, p)))
	for field in FIELDS:
		weight = maxf(weight, 1.0 - smoothstep(0.0, 3.0, _rect_distance(field, p)))
	for point in _level_points:
		weight = maxf(weight, 1.0 - smoothstep(LEVEL_RADIUS, LEVEL_RADIUS + 4.0, p.distance_to(point)))
	weight = maxf(weight, 1.0 - smoothstep(9.0, 14.0, p.distance_to(BARROW)))
	return weight


func color_at(x: float, z: float, height: float) -> Color:
	var p := Vector2(x, z)
	var color := GRASS.lerp(GRASS_LIGHT, _detail.get_noise_2d(x, z) * 0.5 + 0.5)
	color = color.lerp(HILL_GRASS, smoothstep(3.0, 8.0, height))
	for field in FIELDS:
		if _rect_distance(field, p) <= 0.0:
			color = FIELD.lerp(FIELD.darkened(0.12), float(int(floor(x)) % 2 == 0))
	if _rect_distance(QUARRY, p) <= 0.5:
		color = QUARRY_GROUND
	var path := 1.0 - smoothstep(PATH_HALF_WIDTH - 0.4, PATH_HALF_WIDTH + 0.4, _path_distance(p))
	color = color.lerp(DIRT, path)
	if p.distance_to(FORUM) < 4.0:
		color = STONE
	var to_pond := p.distance_to(POND)
	if to_pond < POND_RADIUS + 1.5:
		color = SAND if to_pond > POND_RADIUS - 1.0 else POND_BED
	return color


func is_grassy(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	if maxf(absf(x), absf(z)) < FORT_HALF + 1.0 or _path_distance(p) < PATH_HALF_WIDTH + 0.5:
		return false
	if _rect_distance(QUARRY, p) < 1.0 or p.distance_to(POND) < POND_RADIUS + 2.0:
		return false
	for field in FIELDS:
		if _rect_distance(field, p) < 0.5:
			return false
	return true


func _build_ground() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1) # flat shading: each triangle lit as one face
	var steps := int(HALF_SIZE * 2.0 / CELL)
	for ix in steps:
		for iz in steps:
			var x0 := -HALF_SIZE + ix * CELL
			var z0 := -HALF_SIZE + iz * CELL
			var corners := [Vector2(x0, z0), Vector2(x0 + CELL, z0), Vector2(x0 + CELL, z0 + CELL), Vector2(x0, z0 + CELL)]
			var points := []
			for c in corners:
				points.append(Vector3(c.x, _height_cached(c), c.y))
			# One colour per tile, sampled at its centre: crisp OSRS-style tiles.
			var centre := Vector2(x0 + CELL * 0.5, z0 + CELL * 0.5)
			tool.set_color(color_at(centre.x, centre.y, (points[0].y + points[2].y) * 0.5))
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


func _build_pond() -> void:
	var water := MeshInstance3D.new()
	water.name = "Pond"
	var disc := PlaneMesh.new()
	disc.size = Vector2(POND_RADIUS * 2.4, POND_RADIUS * 2.4)
	disc.subdivide_width = 12
	disc.subdivide_depth = 12
	var material := ShaderMaterial.new()
	material.shader = WaterShader
	disc.material = material
	water.mesh = disc
	water.position = Vector3(POND.x, WATER_LEVEL, POND.y)
	add_child(water)
	# Keep walkers out of the water.
	var blocker := StaticBody3D.new()
	blocker.name = "PondEdge"
	# The pond is a sacred spring: wash here to cleanse ritual pollution.
	blocker.add_to_group("springs")
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = POND_RADIUS - 0.5
	cylinder.height = 3.0
	shape.shape = cylinder
	blocker.add_child(shape)
	blocker.position = Vector3(POND.x, 0.5, POND.y)
	add_child(blocker)


func _build_grass() -> void:
	_grass = MultiMeshInstance3D.new()
	_grass.name = "Grass"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _tuft_mesh()
	_grass.multimesh = multimesh
	_grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grass.visibility_range_end = 70.0
	add_child(_grass)


func set_grass_count(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var transforms: Array[Transform3D] = []
	var attempts := 0
	while transforms.size() < count and attempts < count * 6:
		attempts += 1
		var x := rng.randf_range(-62.0, 62.0)
		var z := rng.randf_range(-62.0, 62.0)
		if not is_grassy(x, z):
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3))
		transforms.append(Transform3D(basis, Vector3(x, height_at(x, z), z)))
	_grass.multimesh.instance_count = transforms.size()
	for i in transforms.size():
		_grass.multimesh.set_instance_transform(i, transforms[i])


func grass_count() -> int:
	return _grass.multimesh.instance_count


func _on_graphics_changed() -> void:
	set_grass_count(GRASS_COUNT.get(graphics_settings.preset, 3000))


## Three crossed blades, darker at the root.
func _tuft_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var angle := TAU * i / 3.0
		var side := Vector3(cos(angle), 0, sin(angle)) * 0.16
		var lean := Vector3(-sin(angle), 0, cos(angle)) * 0.06
		tool.set_color(Color(0.42, 0.6, 0.25))
		tool.add_vertex(-side)
		tool.set_color(Color(0.42, 0.6, 0.25))
		tool.add_vertex(side)
		tool.set_color(Color(0.64, 0.78, 0.38))
		tool.add_vertex(Vector3(0, 0.3, 0) + lean)
	tool.generate_normals()
	var mesh := tool.commit()
	var material := ShaderMaterial.new()
	material.shader = GrassShader
	mesh.surface_set_material(0, material)
	return mesh


func _path_distance(p: Vector2) -> float:
	var best := INF
	for path in PATHS:
		for i in path.size() - 1:
			best = minf(best, _segment_distance(p, path[i], path[i + 1]))
	return best


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## 0 inside the rectangle, otherwise the distance to its edge.
static func _rect_distance(rect: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(rect.position.x - p.x, 0.0), p.x - rect.end.x)
	var dz := maxf(maxf(rect.position.y - p.y, 0.0), p.y - rect.end.y)
	return Vector2(dx, dz).length()
