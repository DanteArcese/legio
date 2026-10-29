extends StaticBody3D
## Vipasca: a silver-mining town in the dry hills of Hispania, built at
## startup in the overworld's low-poly style. A small town yard (bank chest,
## furnace, anvil, the procurator's office) sits at the north end; a track
## runs south past olive scrub to an open-cast pit ringed with red spoil
## heaps, where a Roman drainage wheel turns, and on to the mouth of the deep
## gallery.
##
## It lies far south of Castra Ferrea (z around 400) and is reached by the
## road leaving the fort's fields to the south-east.

const X_MIN := -60.0
const X_MAX := 60.0
const Z_MIN := 340.0
const Z_MAX := 460.0
const CELL := 1.0
const PAD := 30.0
## Kept flat: the town yard, the tracks, the pit and the gallery mouth.
const TOWN := Rect2(-22, 343, 44, 22)
const PATHS := [
	[Vector2(0, 343), Vector2(0, 372), Vector2(-4, 392)],
	[Vector2(-4, 392), Vector2(-20, 428)],
]
const PIT := Vector2(-4, 404)
const PIT_RADIUS := 15.0
## Where the track ends, under the hill: the gallery mouth.
const GALLERY := Rect2(-30, 428, 20, 14)
const WHEEL := Vector3(8, 0, 399)
## The lamiae's ruined shrine in the south-east hills, and the centaurs'
## grassland in the north-east, both kept flat.
const SHRINE := Vector2(40, 425)
const SHRINE_RADIUS := 7.0
const GRASSLAND := Rect2(28, 350, 24, 18)
const MARBLE := Color(0.84, 0.8, 0.72)
const SCRUB_COUNT := 140
const SCRUB_CLEARANCE := 3.5

const EARTH := Color(0.71, 0.55, 0.36)
const EARTH_LIGHT := Color(0.78, 0.63, 0.41)
const DRY_GRASS := Color(0.62, 0.58, 0.33)
const RED_EARTH := Color(0.62, 0.32, 0.2)
const TRACK := Color(0.6, 0.46, 0.32)
const PAVING := Color(0.7, 0.66, 0.58)
const ROCK := Color(0.55, 0.47, 0.4)
const TIMBER := Color(0.42, 0.3, 0.19)
const SCRUB := ["plant_bush", "plant_bushDetailed", "plant_bushLarge", "tree_fat", "tree_default"]

@export var dresser: Node

var _noise := FastNoiseLite.new()
var _scrub: Array[Vector2] = []


func _init() -> void:
	collision_layer = 1
	add_to_group("navigation_source")


func _ready() -> void:
	_noise.seed = 77
	_noise.frequency = 0.035
	_build_ground()
	_build_bounds()
	_plant_scrub()
	_build_wheel()
	_build_shrine()
	if dresser:
		_dress()


func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * 2.6
	var flat := 1.0 - smoothstep(0.0, 4.0, _rect_distance(TOWN, p))
	flat = maxf(flat, 1.0 - smoothstep(2.5, 6.0, _path_distance(p)))
	flat = maxf(flat, 1.0 - smoothstep(PIT_RADIUS, PIT_RADIUS + 2.0, p.distance_to(PIT)))
	flat = maxf(flat, 1.0 - smoothstep(0.0, 3.0, _rect_distance(GALLERY, p)))
	flat = maxf(flat, 1.0 - smoothstep(SHRINE_RADIUS, SHRINE_RADIUS + 3.0, p.distance_to(SHRINE)))
	flat = maxf(flat, 1.0 - smoothstep(0.0, 4.0, _rect_distance(GRASSLAND, p)))
	h = lerpf(h, 0.0, flat)
	# Spoil heaps ring the pit: everything dug out of it, piled up round it.
	var ring := absf(p.distance_to(PIT) - (PIT_RADIUS + 5.0))
	var gap := smoothstep(4.0, 7.0, _path_distance(p))
	h += (1.0 - smoothstep(0.0, 4.0, ring)) * 3.2 * gap
	# The gallery is cut into a hill that rises behind it.
	var behind := smoothstep(GALLERY.end.y - 2.0, GALLERY.end.y + 8.0, z)
	h += smoothstep(14.0, 2.0, _rect_distance(GALLERY, p)) * behind * 7.0
	# Hills rise beyond the walkable edges, framing the view.
	var edge := maxf(smoothstep(X_MAX - 6.0, X_MAX + PAD, x), smoothstep(X_MIN + 6.0, X_MIN - PAD, x))
	edge = maxf(edge, maxf(smoothstep(Z_MAX - 6.0, Z_MAX + PAD, z), smoothstep(Z_MIN + 2.0, Z_MIN - PAD, z)))
	return h + edge * 10.0


func color_at(x: float, z: float, height: float) -> Color:
	var p := Vector2(x, z)
	if TOWN.grow(-2.0).has_point(p):
		return PAVING
	if _path_distance(p) < 1.8:
		return TRACK
	if p.distance_to(PIT) < PIT_RADIUS + 8.0 or GALLERY.grow(3.0).has_point(p):
		return RED_EARTH.lerp(EARTH, clampf(_noise.get_noise_2d(x * 3.0, z * 3.0) * 0.6 + 0.3, 0.0, 1.0))
	if height > 4.0:
		return ROCK
	var shade := _noise.get_noise_2d(x * 4.0, z * 4.0) * 0.5 + 0.5
	if _noise.get_noise_2d(x * 1.3 + 40.0, z * 1.3) > 0.1:
		return DRY_GRASS.lerp(EARTH_LIGHT, shade * 0.5)
	return EARTH.lerp(EARTH_LIGHT, shade)


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
		for iz in int((Z_MAX - Z_MIN + PAD * 2.0) / CELL):
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


## Invisible walls at the walkable edges.
func _build_bounds() -> void:
	for z in [Z_MIN + 1.0, Z_MAX - 1.0]:
		_solid(Vector3(X_MAX - X_MIN, 8.0, 0.6), Vector3(0, 2.0, z))
	for x in [X_MIN + 1.0, X_MAX - 1.0]:
		_solid(Vector3(0.6, 8.0, Z_MAX - Z_MIN), Vector3(x, 2.0, (Z_MIN + Z_MAX) / 2.0))


## Olive scrub and bushes on the dry slopes; the dresser adds the models.
## Placement is seeded, so it never changes.
func _plant_scrub() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5301
	var planted := 0
	var tries := 0
	while planted < SCRUB_COUNT and tries < SCRUB_COUNT * 20:
		tries += 1
		var p := Vector2(rng.randf_range(X_MIN + 3.0, X_MAX - 3.0), rng.randf_range(Z_MIN + 4.0, Z_MAX - 3.0))
		if not _clear_for_scrub(p):
			continue
		var bush := Node3D.new()
		bush.name = "Scrub%d" % planted
		bush.position = Vector3(p.x, height_at(p.x, p.y), p.y)
		var model: String = SCRUB[rng.randi() % SCRUB.size()]
		bush.set_meta("model", model)
		bush.set_meta("scale", rng.randf_range(1.4, 2.0) if model.begins_with("tree") else rng.randf_range(1.5, 2.6))
		bush.rotation.y = rng.randf() * TAU
		add_child(bush)
		if model.begins_with("tree"):
			var shape := CollisionShape3D.new()
			shape.shape = CylinderShape3D.new()
			shape.shape.radius = 0.3
			shape.shape.height = 2.0
			shape.position = bush.position + Vector3(0, 1.0, 0)
			add_child(shape)
		_scrub.append(p)
		planted += 1


func _clear_for_scrub(p: Vector2) -> bool:
	if _path_distance(p) < SCRUB_CLEARANCE or p.distance_to(PIT) < PIT_RADIUS + 9.0:
		return false
	if _rect_distance(TOWN, p) < SCRUB_CLEARANCE or _rect_distance(GALLERY, p) < SCRUB_CLEARANCE:
		return false
	if Vector2(WHEEL.x, WHEEL.z).distance_to(p) < 6.0:
		return false
	if p.distance_to(SHRINE) < SHRINE_RADIUS + 2.0 or _rect_distance(GRASSLAND, p) < 1.0:
		return false
	return not _scrub.any(func(other: Vector2): return other.distance_to(p) < 3.0)


## A Roman drainage wheel by the pit: a big timber wheel with buckets, on a
## frame, turning slowly. Built from primitives so it needs no assets.
func _build_wheel() -> void:
	var frame := Node3D.new()
	frame.name = "DrainageWheel"
	frame.position = WHEEL
	add_child(frame)
	for side in [-1.0, 1.0]:
		_box(frame, Vector3(0.3, 4.2, 0.3), Vector3(side * 0.9, 2.1, -1.4), TIMBER.darkened(0.2))
		_box(frame, Vector3(0.3, 4.2, 0.3), Vector3(side * 0.9, 2.1, 1.4), TIMBER.darkened(0.2))
	_box(frame, Vector3(2.1, 0.25, 0.25), Vector3(0, 3.6, 0), TIMBER.darkened(0.3))
	var wheel := Node3D.new()
	wheel.name = "Wheel"
	wheel.position = Vector3(0, 3.6, 0)
	frame.add_child(wheel)
	var spokes := 12
	for i in spokes:
		var angle := TAU * i / spokes
		var spoke := _box(wheel, Vector3(0.14, 3.2, 0.14), Vector3.ZERO, TIMBER)
		spoke.rotation.x = angle
		var rim := _box(wheel, Vector3(1.2, 0.2, 0.95), Vector3(0, cos(angle), sin(angle)) * 3.2, TIMBER.lightened(0.1))
		rim.rotation.x = angle
		var bucket := _box(wheel, Vector3(1.0, 0.4, 0.4), Vector3(0, cos(angle), sin(angle)) * 3.45, TIMBER.darkened(0.15))
		bucket.rotation.x = angle
	_solid(Vector3(2.4, 4.0, 3.4), WHEEL + Vector3(0, 2.0, 0))


## A ruined shrine where the lamiae nest: a marble floor, a ring of columns
## (most broken off), and a fallen one across the steps.
func _build_shrine() -> void:
	var shrine := Node3D.new()
	shrine.name = "LamiaShrine"
	shrine.position = Vector3(SHRINE.x, 0, SHRINE.y)
	add_child(shrine)
	_box(shrine, Vector3(9, 0.3, 9), Vector3(0, 0.15, 0), MARBLE.darkened(0.1))
	var heights := [3.4, 1.2, 2.6, 0.8, 3.4, 1.6, 0.6, 2.2]
	for i in heights.size():
		var angle := TAU * i / heights.size()
		var at := Vector3(cos(angle), 0, sin(angle)) * 3.6
		var column := _box(shrine, Vector3(0.55, heights[i], 0.55), at + Vector3(0, 0.3 + heights[i] / 2.0, 0), MARBLE)
		column.rotation.y = angle
		_solid(Vector3(0.55, heights[i], 0.55), Vector3(SHRINE.x, 0.3 + heights[i] / 2.0, SHRINE.y) + at)
	var fallen := _box(shrine, Vector3(0.55, 0.55, 3.0), Vector3(-1.0, 0.58, -5.3), MARBLE.darkened(0.05))
	fallen.rotation.y = 0.4


func _process(delta: float) -> void:
	var wheel := get_node_or_null("DrainageWheel/Wheel")
	if wheel:
		wheel.rotation.x += delta * 0.25


## Scrub models, mine carts and timber props, and the gallery's timber mouth.
func _dress() -> void:
	for bush in get_children():
		if bush.has_meta("model"):
			var model: Node3D = dresser.model("nature/" + bush.get_meta("model"))
			model.scale = Vector3.ONE * float(bush.get_meta("scale"))
			bush.add_child(model)
	for spec in [[Vector3(-12, 0, 392), 0.6], [Vector3(6, 0, 418), -0.9], [Vector3(-3, 0, 366), 1.4]]:
		var cart: Node3D = dresser.model("town/cart")
		cart.position = spec[0]
		cart.rotation.y = spec[1]
		add_child(cart)
		_solid(Vector3(1.4, 1.2, 2.0), spec[0] + Vector3(0, 0.6, 0))
	for spec in [[Vector2(-18, 398), "rock_largeA"], [Vector2(9, 412), "rock_largeC"], [Vector2(-14, 414), "rock_smallA"],
			[Vector2(4, 394), "rock_smallA"]]:
		var rock: Node3D = dresser.model("nature/" + spec[1])
		rock.position = Vector3(spec[0].x, height_at(spec[0].x, spec[0].y) - 0.1, spec[0].y)
		rock.scale = Vector3.ONE * 1.8
		add_child(rock)
	# The gallery mouth: two timber posts and a lintel against the hill.
	var mouth := Vector3(GALLERY.get_center().x, 0, GALLERY.end.y - 1.0)
	for side in [-1.0, 1.0]:
		_box(self, Vector3(0.4, 3.0, 0.4), mouth + Vector3(side * 1.6, 1.5, 0), TIMBER)
	_box(self, Vector3(3.8, 0.45, 0.5), mouth + Vector3(0, 3.1, 0), TIMBER.darkened(0.1))
	_box(self, Vector3(2.8, 2.8, 0.2), mouth + Vector3(0, 1.4, 0.3), Color(0.05, 0.04, 0.03))


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	box.material = material
	mesh.mesh = box
	mesh.position = at
	parent.add_child(mesh)
	return mesh


func _solid(size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	shape.position = at
	add_child(shape)


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
