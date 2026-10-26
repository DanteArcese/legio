extends StaticBody3D
## Portus Salis, a harbour on the coast, built at startup in the same
## low-poly style as the overworld: flat-shaded 1 m tiles of grass, road,
## sand, and rock, a beach running down into the sea, and a timber pier.
##
## It lies far west of Castra Ferrea (x around -300) and is reached by the
## road; invisible walls keep walkers on land, with a gap onto the pier.

const WaterShader := preload("res://shaders/water.gdshader")

const X_MIN := -360.0
const X_MAX := -240.0
const Z_MIN := -50.0
const Z_MAX := 50.0
const CELL := 1.0
## The ground runs on past the walkable bounds, so the horizon shows land.
const PAD := 30.0
const WATER_LEVEL := -0.35
const SEA_FLOOR := -1.8
## The beach runs from here (land) down to the water's edge.
const BEACH_START := 5.0
const SHORE := 12.0
## The pier: centre line x, and its deck from the beach out to sea.
const PIER_X := -300.0
const PIER_HALF_WIDTH := 1.5
const PIER_START := 6.0
const PIER_END := 30.0
const PIER_HEIGHT := 0.35
## Kept flat for the town, and the road down to it from the north.
const HARBOUR := Rect2(-330, -26, 50, 32)
const ROAD := [Vector2(-300, -50), Vector2(-300, -26)]
## Rocky ground in the east, where the harpies roost.
const ROCKS_X := -264.0

const GRASS := Color(0.4, 0.57, 0.27)
const GRASS_LIGHT := Color(0.5, 0.63, 0.3)
const SAND := Color(0.84, 0.77, 0.56)
const WET_SAND := Color(0.66, 0.6, 0.45)
const ROAD_DIRT := Color(0.62, 0.5, 0.35)
const ROCK := Color(0.55, 0.53, 0.5)
const PAVING := Color(0.66, 0.63, 0.57)
const TIMBER := Color(0.45, 0.33, 0.22)

var _noise := FastNoiseLite.new()


func _init() -> void:
	collision_layer = 1
	add_to_group("navigation_source")


func _ready() -> void:
	_noise.seed = 21
	_noise.frequency = 0.05
	_build_ground()
	_build_sea()
	_build_pier()
	_build_bounds()


func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := _noise.get_noise_2d(x, z) * 0.9
	if x > ROCKS_X:
		h += smoothstep(ROCKS_X, ROCKS_X + 10.0, x) * (1.2 + _noise.get_noise_2d(x * 3.0, z * 3.0) * 0.8)
	var flat := 1.0 - smoothstep(0.0, 5.0, _rect_distance(HARBOUR, p))
	flat = maxf(flat, 1.0 - smoothstep(4.0, 10.0, _road_distance(p)))
	h = lerpf(h, 0.0, flat)
	# Hills rise beyond the walkable edges, framing the view.
	var edge := maxf(smoothstep(X_MAX - 6.0, X_MAX + PAD, x), smoothstep(X_MIN + 6.0, X_MIN - PAD, x))
	edge = maxf(edge, smoothstep(Z_MIN + 6.0, Z_MIN - PAD, z) * (1.0 - flat * 0.6))
	h += edge * 9.0 * (1.0 - smoothstep(BEACH_START, SHORE, z))
	# The beach slopes gently to the shoreline, then drops into the sea.
	h = lerpf(h, -0.1, smoothstep(BEACH_START - 2.0, SHORE, z))
	return lerpf(h, SEA_FLOOR, smoothstep(SHORE - 0.5, SHORE + 5.0, z))


func color_at(x: float, z: float, height: float) -> Color:
	var p := Vector2(x, z)
	if height < WATER_LEVEL + 0.1:
		return WET_SAND
	if z > BEACH_START - 0.5:
		return SAND
	if _road_distance(p) < 2.0 or (HARBOUR.grow(-4.0).has_point(p) and absf(x - PIER_X) < 3.0):
		return ROAD_DIRT
	if HARBOUR.grow(-6.0).has_point(p) and z > -12.0:
		return PAVING
	if x > ROCKS_X + 3.0 and height > 0.5:
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
			var z0 := Z_MIN - PAD + iz * CELL
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
	material.shader = WaterShader
	plane.material = material
	water.mesh = plane
	water.position = Vector3((X_MIN + X_MAX) / 2.0, WATER_LEVEL, SHORE - 4.0 + 35.0)
	add_child(water)


## A timber deck on posts, with railings so nobody walks off into the sea.
func _build_pier() -> void:
	var length := PIER_END - PIER_START
	var centre := Vector3(PIER_X, PIER_HEIGHT / 2.0, PIER_START + length / 2.0)
	_solid(Vector3(PIER_HALF_WIDTH * 2.0, PIER_HEIGHT + 2.0, length), centre - Vector3(0, 1.0, 0), TIMBER, false)
	_visual_box(Vector3(PIER_HALF_WIDTH * 2.0, 0.12, length), Vector3(PIER_X, PIER_HEIGHT, centre.z), TIMBER)
	for side: float in [-1.0, 1.0]:
		var x := PIER_X + side * (PIER_HALF_WIDTH + 0.05)
		_solid(Vector3(0.12, 1.0, length - (SHORE - PIER_START)), Vector3(x, PIER_HEIGHT + 0.5, (SHORE + PIER_END) / 2.0), TIMBER.darkened(0.2), true)
		var z := PIER_START + 1.0
		while z < PIER_END:
			_visual_box(Vector3(0.22, 2.2, 0.22), Vector3(x, PIER_HEIGHT - 0.9, z), TIMBER.darkened(0.35))
			z += 3.0
	_solid(Vector3(PIER_HALF_WIDTH * 2.2, 1.0, 0.12), Vector3(PIER_X, PIER_HEIGHT + 0.5, PIER_END + 0.05), TIMBER.darkened(0.2), true)
	# A gentle ramp up from the ground: walkers can't climb even a low step.
	var run := 3.0
	var rise := PIER_HEIGHT + 0.05
	var slope := atan2(rise, run)
	var ramp := CollisionShape3D.new()
	ramp.shape = BoxShape3D.new()
	ramp.shape.size = Vector3(PIER_HALF_WIDTH * 2.0, 0.2, sqrt(run * run + rise * rise))
	ramp.position = Vector3(PIER_X, rise / 2.0 - 0.1, PIER_START - run / 2.0)
	ramp.rotation.x = -slope
	add_child(ramp)
	var ramp_look := MeshInstance3D.new()
	var ramp_mesh := BoxMesh.new()
	ramp_mesh.size = ramp.shape.size
	var wood := StandardMaterial3D.new()
	wood.albedo_color = TIMBER
	ramp_mesh.material = wood
	ramp_look.mesh = ramp_mesh
	ramp_look.position = ramp.position
	ramp_look.rotation = ramp.rotation
	add_child(ramp_look)


## Invisible walls: the shoreline (with a gap for the pier) and the edges.
func _build_bounds() -> void:
	var left := PIER_X - PIER_HALF_WIDTH - X_MIN
	var right := X_MAX - (PIER_X + PIER_HALF_WIDTH)
	_solid(Vector3(left, 4.0, 0.6), Vector3(X_MIN + left / 2.0, 1.0, SHORE), Color.WHITE, false)
	_solid(Vector3(right, 4.0, 0.6), Vector3(X_MAX - right / 2.0, 1.0, SHORE), Color.WHITE, false)
	_solid(Vector3(X_MAX - X_MIN, 8.0, 0.6), Vector3((X_MIN + X_MAX) / 2.0, 2.0, Z_MIN + 1.0), Color.WHITE, false)
	for x in [X_MIN + 1.0, X_MAX - 1.0]:
		_solid(Vector3(0.6, 8.0, Z_MAX - Z_MIN), Vector3(x, 2.0, 0.0), Color.WHITE, false)


## A collision box, optionally visible, added as part of the coast's body.
func _solid(size: Vector3, at: Vector3, color: Color, visible_box: bool) -> void:
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	shape.position = at
	add_child(shape)
	if visible_box:
		_visual_box(size, at, color)


func _visual_box(size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	box.material = material
	mesh.mesh = box
	mesh.position = at
	add_child(mesh)


func _road_distance(p: Vector2) -> float:
	return Geometry2D.get_closest_point_to_segment(p, ROAD[0], ROAD[1]).distance_to(p)


static func _rect_distance(rect: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(rect.position.x - p.x, 0.0), p.x - rect.end.x)
	var dz := maxf(maxf(rect.position.y - p.y, 0.0), p.y - rect.end.y)
	return Vector2(dx, dz).length()
