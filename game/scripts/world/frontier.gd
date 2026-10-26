extends StaticBody3D
## Beyond the Limes: the frontier north of the fort, built at startup in the
## overworld's low-poly style. A timber palisade (the limes) runs east to
## west with one gap; south of it is a small Roman yard, north of it dark
## pine forest, a raiders' camp, and a seam of gold.
##
## North of the palisade is the danger zone: deaths there drop everything but
## the 3 most valuable items on the ground (see graves.gd). The driver
## registers danger_area with the simulation.
##
## It lies far north of Castra Ferrea (z around -400) and is reached by the
## gate at the end of the north road.

const X_MIN := -60.0
const X_MAX := 60.0
const Z_MIN := -460.0
const Z_MAX := -340.0
const CELL := 1.0
const PAD := 30.0
## The palisade line, and the half-width of the gap through it.
const LIMES_Z := -350.0
const GAP := 2.0
const POST_SPACING := 0.45
const POST_HEIGHT := 3.2
## Kept flat: the Roman yard, the path north, the camp, and the mine.
const YARD := Rect2(-12, -350, 24, 10)
## Paths as 2D polylines (x, z): north from the gate, then to the camp and to the mine.
const PATHS := [
	[Vector2(0, -350), Vector2(0, -372), Vector2(14, -402), Vector2(24, -410)],
	[Vector2(0, -372), Vector2(-14, -400), Vector2(-27, -428)],
]
const CAMP := Vector2(24, -412)
const CAMP_RADIUS := 9.0
const MINE := Rect2(-38, -440, 16, 12)
const TREE_COUNT := 260
## Trees keep clear of the paths, the camp, the mine, and the palisade.
const TREE_CLEARANCE := 4.0

const GRASS := Color(0.27, 0.42, 0.2)
const GRASS_LIGHT := Color(0.33, 0.47, 0.22)
const NEEDLES := Color(0.36, 0.3, 0.2)
const DIRT := Color(0.5, 0.4, 0.28)
const ROCK := Color(0.47, 0.45, 0.42)
const TIMBER := Color(0.42, 0.3, 0.19)
const PINES := ["tree_pineTallA", "tree_pineTallB", "tree_pineTallC", "tree_pineDefaultA", "tree_pineDefaultB", "tree_pineRoundC"]

## North of the palisade: the danger zone, as an XZ rectangle.
var danger_area := Rect2(X_MIN, Z_MIN, X_MAX - X_MIN, LIMES_Z - Z_MIN)

@export var dresser: Node

var _noise := FastNoiseLite.new()
var _trees: Array[Vector2] = []


func _init() -> void:
	collision_layer = 1
	add_to_group("navigation_source")
	add_to_group("danger_zones")


func _ready() -> void:
	_noise.seed = 43
	_noise.frequency = 0.04
	_build_ground()
	_build_palisade()
	_build_bounds()
	_plant_forest()
	if dresser:
		_dress()


func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * 2.2
	var flat := 1.0 - smoothstep(0.0, 4.0, _rect_distance(YARD, p))
	flat = maxf(flat, 1.0 - smoothstep(2.5, 6.0, _path_distance(p)))
	flat = maxf(flat, 1.0 - smoothstep(CAMP_RADIUS, CAMP_RADIUS + 4.0, p.distance_to(CAMP)))
	flat = maxf(flat, 1.0 - smoothstep(0.0, 4.0, _rect_distance(MINE, p)))
	flat = maxf(flat, 1.0 - smoothstep(1.0, 4.0, absf(z - LIMES_Z)))
	h = lerpf(h, 0.0, flat)
	# Hills rise beyond the walkable edges, framing the view.
	var edge := maxf(smoothstep(X_MAX - 6.0, X_MAX + PAD, x), smoothstep(X_MIN + 6.0, X_MIN - PAD, x))
	edge = maxf(edge, maxf(smoothstep(Z_MIN + 6.0, Z_MIN - PAD, z), smoothstep(Z_MAX - 2.0, Z_MAX + PAD, z)))
	# The mine sits under a rocky ridge to its north.
	var north := smoothstep(MINE.position.y + 2.0, MINE.position.y - 6.0, z)
	var ridge := smoothstep(16.0, 2.0, _rect_distance(MINE, p)) * north * (1.0 - flat) * 4.0
	return h + edge * 10.0 + ridge


func color_at(x: float, z: float, height: float) -> Color:
	var p := Vector2(x, z)
	if _path_distance(p) < 1.8 or YARD.grow(-1.0).has_point(p) or p.distance_to(CAMP) < CAMP_RADIUS - 2.0:
		return DIRT
	if MINE.has_point(p) or height > 2.6:
		return ROCK
	var shade := _noise.get_noise_2d(x * 4.0, z * 4.0) * 0.5 + 0.5
	if z < LIMES_Z and _noise.get_noise_2d(x * 1.5 + 50.0, z * 1.5) > 0.15:
		return NEEDLES.lerp(GRASS, shade * 0.6)
	return GRASS.lerp(GRASS_LIGHT, shade)


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


## Sharpened logs side by side, with a gap at x = 0 for the gate.
func _build_palisade() -> void:
	var posts := MultiMesh.new()
	posts.transform_format = MultiMesh.TRANSFORM_3D
	var post := CylinderMesh.new()
	post.top_radius = 0.12
	post.bottom_radius = 0.24
	post.height = POST_HEIGHT
	post.radial_segments = 6
	var wood := StandardMaterial3D.new()
	wood.albedo_color = TIMBER
	post.material = wood
	posts.mesh = post
	var xs := []
	var x := X_MIN
	while x <= X_MAX:
		if absf(x) > GAP:
			xs.append(x)
		x += POST_SPACING
	posts.instance_count = xs.size()
	for i in xs.size():
		var wobble := _noise.get_noise_2d(xs[i] * 9.0, 7.0)
		var basis := Basis.from_euler(Vector3(wobble * 0.05, 0, wobble * 0.04))
		posts.set_instance_transform(i, Transform3D(basis.scaled(Vector3(1, 1.0 + wobble * 0.12, 1)), Vector3(xs[i], POST_HEIGHT / 2.0 - 0.2, LIMES_Z)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Palisade"
	instance.multimesh = posts
	add_child(instance)
	for side: float in [-1.0, 1.0]:
		var length := X_MAX - GAP
		_solid(Vector3(length, 4.0, 0.6), Vector3(side * (GAP + length / 2.0), 2.0, LIMES_Z))


## Invisible walls at the walkable edges.
func _build_bounds() -> void:
	for z in [Z_MIN + 1.0, Z_MAX - 1.0]:
		_solid(Vector3(X_MAX - X_MIN, 8.0, 0.6), Vector3(0, 2.0, z))
	for x in [X_MIN + 1.0, X_MAX - 1.0]:
		_solid(Vector3(0.6, 8.0, Z_MAX - Z_MIN), Vector3(x, 2.0, (Z_MIN + Z_MAX) / 2.0))


## Tree trunks are solid (so the navmesh routes round them); the dresser
## adds the pine models on top. Placement is seeded, so it never changes.
func _plant_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4401
	var planted := 0
	var tries := 0
	while planted < TREE_COUNT and tries < TREE_COUNT * 20:
		tries += 1
		var p := Vector2(rng.randf_range(X_MIN + 3.0, X_MAX - 3.0), rng.randf_range(Z_MIN + 3.0, LIMES_Z - TREE_CLEARANCE))
		if not _clear_for_tree(p):
			continue
		var tree := Node3D.new()
		tree.name = "Pine%d" % planted
		tree.position = Vector3(p.x, height_at(p.x, p.y), p.y)
		tree.set_meta("model", PINES[rng.randi() % PINES.size()])
		tree.set_meta("scale", rng.randf_range(2.2, 3.4))
		tree.rotation.y = rng.randf() * TAU
		add_child(tree)
		var shape := CollisionShape3D.new()
		shape.shape = CylinderShape3D.new()
		shape.shape.radius = 0.4
		shape.shape.height = 3.0
		shape.position = tree.position + Vector3(0, 1.5, 0)
		add_child(shape)
		_trees.append(p)
		planted += 1


func _clear_for_tree(p: Vector2) -> bool:
	if _path_distance(p) < TREE_CLEARANCE or p.distance_to(CAMP) < CAMP_RADIUS + 2.0:
		return false
	if _rect_distance(MINE, p) < TREE_CLEARANCE or _rect_distance(YARD, p) < TREE_CLEARANCE:
		return false
	return not _trees.any(func(other: Vector2): return other.distance_to(p) < 3.0)


## Pines, a Roman watchtower by the gate, and the raiders' camp.
func _dress() -> void:
	for tree in get_children():
		if tree.has_meta("model"):
			var model: Node3D = dresser.model("nature/" + tree.get_meta("model"))
			model.scale = Vector3.ONE * tree.get_meta("scale")
			tree.add_child(model)
	for side: float in [-1.0, 1.0]:
		var tower := Node3D.new()
		tower.position = Vector3(side * 4.5, 0, LIMES_Z + 2.2)
		add_child(tower)
		var y := 0.0
		for part in ["castle/tower-square-base", "castle/tower-square-mid", "castle/tower-square-top"]:
			var piece: Node3D = dresser.model(part)
			piece.position.y = y
			piece.scale = Vector3.ONE * 3.0
			tower.add_child(piece)
			y += 3.0 * (1.0 if part != "castle/tower-square-top" else 0.3)
		_solid(Vector3(3.0, 6.0, 3.0), tower.position + Vector3(0, 3.0, 0))
	for i in 5:
		var angle := TAU * i / 5.0 + 0.4
		var spot := CAMP + Vector2(cos(angle), sin(angle)) * 5.5
		var logs: Node3D = dresser.model("nature/log")
		logs.position = Vector3(spot.x, 0, spot.y)
		logs.rotation.y = angle + PI / 2.0
		logs.scale = Vector3.ONE * 2.2
		add_child(logs)
	for spec in [[Vector2(-35, -444), "rock_largeA"], [Vector2(-26, -445), "rock_tallA"], [Vector2(-18, -443), "rock_largeC"]]:
		var rock: Node3D = dresser.model("nature/" + spec[1])
		rock.position = Vector3(spec[0].x, height_at(spec[0].x, spec[0].y) - 0.2, spec[0].y)
		rock.scale = Vector3.ONE * 3.0
		add_child(rock)
		_solid(Vector3(2.4, 3.0, 2.4), rock.position + Vector3(0, 1.0, 0))


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
