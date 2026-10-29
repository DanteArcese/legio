extends StaticBody3D
## Rome, for citizens: built at startup in the overworld's low-poly style.
## Merchant ships from Portus Salis tie up at a stone quay on the Tiber, along
## the south edge; a street climbs north to the forum, with the temple of
## Jupiter at its west end, the basilica along its north side, and the
## rostra. Brick insulae crowd the north-east (the Subura); town houses line
## the streets; open ground in the south-east is kept for the Circus
## Maximus. The Servian wall rings the rest.
##
## It lies far west of everything else (x around -570), beyond the sea.

const X_MIN := -640.0
const X_MAX := -500.0
const Z_MIN := -70.0
const Z_MAX := 70.0
const CELL := 1.0
const PAD := 24.0
const WATER_LEVEL := -0.35
const RIVER_FLOOR := -1.6
## The Tiber's north bank, along the south edge (larger z is river).
const BANK := 56.0
## The quay: a stone embankment where the ships tie up.
const QUAY := Rect2(-604, 50, 28, 6)
const QUAY_HEIGHT := 0.15
const FORUM := Rect2(-602, -22, 52, 30)
const TEMPLE := Rect2(-624, -18, 16, 22)
const BASILICA := Rect2(-596, -36, 40, 10)
## Kept clear: the Subura's insulae (north-east) and the Circus Maximus.
const SUBURA := Rect2(-548, -62, 42, 38)
const CIRCUS := Rect2(-566, 14, 60, 34)
const STREETS := [
	[Vector2(-590, 50), Vector2(-590, 8)],
	[Vector2(-550, -8), Vector2(-528, -8), Vector2(-528, -24)],
	[Vector2(-602, 0), Vector2(-608, 0)],
	[Vector2(-575, 8), Vector2(-560, 14)],
	[Vector2(-576, -22), Vector2(-576, -40)],
]

const PAVING := Color(0.78, 0.74, 0.66)
const STREET := Color(0.56, 0.54, 0.5)
const GARDEN := Color(0.5, 0.56, 0.32)
const DUST := Color(0.66, 0.58, 0.44)
const SAND := Color(0.82, 0.72, 0.52)
const MUD := Color(0.42, 0.36, 0.28)
const MARBLE := Color(0.92, 0.9, 0.86)
const TRAVERTINE := Color(0.84, 0.8, 0.7)
const BRICK := Color(0.66, 0.38, 0.27)
const TILE := Color(0.62, 0.3, 0.2)
const PLASTER := Color(0.88, 0.82, 0.7)
const TUFF := Color(0.62, 0.58, 0.48)
const TIMBER := Color(0.45, 0.33, 0.22)

@export var dresser: Node

var _noise := FastNoiseLite.new()


func _init() -> void:
	collision_layer = 1
	add_to_group("navigation_source")


func _ready() -> void:
	_noise.seed = 753
	_noise.frequency = 0.05
	_build_ground()
	_build_river()
	_build_quay()
	_build_bounds()
	_build_walls()
	_build_temple()
	_build_basilica()
	_build_rostra()
	_build_insulae()
	_build_houses()
	_build_circus()
	if dresser:
		_dress()


## Rome is flat where people live: the ground only rises a little in the
## gardens between, and drops to the river beyond the bank.
func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * 0.8
	var flat := 1.0 - smoothstep(0.0, 3.0, _rect_distance(FORUM.merge(TEMPLE).merge(BASILICA), p))
	flat = maxf(flat, 1.0 - smoothstep(1.5, 4.0, _street_distance(p)))
	flat = maxf(flat, 1.0 - smoothstep(0.0, 3.0, _rect_distance(SUBURA, p)))
	flat = maxf(flat, 1.0 - smoothstep(0.0, 3.0, _rect_distance(CIRCUS, p)))
	flat = maxf(flat, 1.0 - smoothstep(0.0, 2.0, _rect_distance(QUAY, p)))
	h = lerpf(h, 0.0, flat)
	# Hills beyond the walls frame the city.
	var edge := maxf(smoothstep(X_MAX - 3.0, X_MAX + PAD, x), smoothstep(X_MIN + 3.0, X_MIN - PAD, x))
	edge = maxf(edge, smoothstep(Z_MIN + 3.0, Z_MIN - PAD, z))
	h += edge * 10.0
	# The bank drops into the Tiber.
	return lerpf(h, RIVER_FLOOR, smoothstep(BANK - 1.0, BANK + 3.0, z))


func color_at(x: float, z: float, height: float) -> Color:
	var p := Vector2(x, z)
	if height < WATER_LEVEL + 0.1:
		return MUD
	if z > BANK - 1.5:
		return SAND
	if FORUM.has_point(p) or TEMPLE.grow(2.0).has_point(p) or BASILICA.grow(2.0).has_point(p):
		return PAVING
	if _street_distance(p) < 2.2:
		return STREET
	if CIRCUS.has_point(p):
		return SAND
	if SUBURA.has_point(p):
		return DUST
	if height > 3.0:
		return TUFF.darkened(0.1)
	return GARDEN.lerp(DUST, _noise.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5)


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


func _build_river() -> void:
	var water := MeshInstance3D.new()
	water.name = "Tiber"
	var plane := PlaneMesh.new()
	plane.size = Vector2(X_MAX - X_MIN + PAD * 2.0, 30.0)
	plane.subdivide_width = 30
	plane.subdivide_depth = 8
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/water.gdshader")
	plane.material = material
	water.mesh = plane
	water.position = Vector3((X_MIN + X_MAX) / 2.0, WATER_LEVEL, BANK + 13.0)
	add_child(water)


## A travertine embankment where the ships tie up, with bollards, and a
## merchant ship moored alongside.
func _build_quay() -> void:
	var centre := QUAY.get_center()
	_solid(Vector3(QUAY.size.x, QUAY_HEIGHT + 2.0, QUAY.size.y), Vector3(centre.x, QUAY_HEIGHT / 2.0 - 1.0, centre.y))
	_box(Vector3(QUAY.size.x, QUAY_HEIGHT + 1.5, QUAY.size.y), Vector3(centre.x, QUAY_HEIGHT / 2.0 - 0.75, centre.y), TRAVERTINE)
	var x := QUAY.position.x + 2.0
	while x < QUAY.end.x:
		_box(Vector3(0.4, 0.6, 0.4), Vector3(x, QUAY_HEIGHT + 0.3, QUAY.end.y - 0.5), TRAVERTINE.darkened(0.2))
		x += 5.0
	var ship := Vector3(centre.x + 4.0, WATER_LEVEL, QUAY.end.y + 2.6)
	_box(Vector3(12.0, 1.4, 3.4), ship + Vector3(0, 0.4, 0), TIMBER)
	_box(Vector3(11.0, 0.15, 3.0), ship + Vector3(0, 1.1, 0), TIMBER.lightened(0.2))
	_box(Vector3(0.25, 7.0, 0.25), ship + Vector3(0, 4.5, 0), TIMBER.darkened(0.2))
	_box(Vector3(0.1, 3.6, 4.2), ship + Vector3(0.2, 5.0, 0), Color(0.85, 0.8, 0.68))


## Invisible walls at the walkable edges, open only at the quay.
func _build_bounds() -> void:
	_solid(Vector3(X_MAX - X_MIN, 8.0, 0.6), Vector3((X_MIN + X_MAX) / 2.0, 2.0, Z_MIN + 1.0))
	for side_x in [X_MIN + 1.0, X_MAX - 1.0]:
		_solid(Vector3(0.6, 8.0, Z_MAX - Z_MIN), Vector3(side_x, 2.0, (Z_MIN + Z_MAX) / 2.0))
	var left := QUAY.position.x - X_MIN
	var right := X_MAX - QUAY.end.x
	_solid(Vector3(left, 4.0, 0.6), Vector3(X_MIN + left / 2.0, 1.0, BANK - 1.0))
	_solid(Vector3(right, 4.0, 0.6), Vector3(X_MAX - right / 2.0, 1.0, BANK - 1.0))
	_solid(Vector3(QUAY.size.x, 4.0, 0.6), Vector3(QUAY.get_center().x, 1.0, QUAY.end.y + 0.4))


## The Servian wall: big tuff blocks along the north, east and west.
func _build_walls() -> void:
	var height := 5.0
	_box(Vector3(X_MAX - X_MIN, height, 2.0), Vector3((X_MIN + X_MAX) / 2.0, height / 2.0, Z_MIN + 2.0), TUFF)
	for side_x in [X_MIN + 2.0, X_MAX - 2.0]:
		_box(Vector3(2.0, height, BANK - Z_MIN - 2.0), Vector3(side_x, height / 2.0, (Z_MIN + BANK) / 2.0), TUFF)
	for i in 6:
		var x := lerpf(X_MIN + 12.0, X_MAX - 12.0, i / 5.0)
		_box(Vector3(4.0, height + 2.0, 3.4), Vector3(x, (height + 2.0) / 2.0, Z_MIN + 2.0), TUFF.darkened(0.08))


## The temple of Jupiter on its podium at the forum's west end: steps up
## the front (east), a portico of columns, and a red-tiled pediment.
func _build_temple() -> void:
	var c := TEMPLE.get_center()
	var podium := 1.2
	_box(Vector3(TEMPLE.size.x, podium, TEMPLE.size.y), Vector3(c.x, podium / 2.0, c.y), TRAVERTINE)
	_solid(Vector3(TEMPLE.size.x, podium, TEMPLE.size.y), Vector3(c.x, podium / 2.0, c.y))
	for step in 3:
		var w := 2.4 - step * 0.8
		_box(Vector3(w, (step + 1) * 0.4, 10.0), Vector3(TEMPLE.end.x + w / 2.0, (step + 1) * 0.2, c.y), TRAVERTINE.lightened(0.05))
		_solid(Vector3(w, (step + 1) * 0.4, 10.0), Vector3(TEMPLE.end.x + w / 2.0, (step + 1) * 0.2, c.y))
	_box(Vector3(TEMPLE.size.x - 6.0, 6.0, TEMPLE.size.y - 4.0), Vector3(c.x - 3.0, podium + 3.0, c.y), PLASTER)
	_solid(Vector3(TEMPLE.size.x - 6.0, 6.0, TEMPLE.size.y - 4.0), Vector3(c.x - 3.0, podium + 3.0, c.y))
	for i in 6:
		var z := lerpf(TEMPLE.position.y + 1.5, TEMPLE.end.y - 1.5, i / 5.0)
		var column := _cylinder(0.45, 6.0, MARBLE)
		column.position = Vector3(TEMPLE.end.x - 1.2, podium + 3.0, z)
		_solid(Vector3(0.9, 6.0, 0.9), column.position)
	var roof := _box(Vector3(TEMPLE.size.x + 0.6, 0.8, TEMPLE.size.y + 0.6), Vector3(c.x, podium + 6.4, c.y), TILE)
	roof.name = "TempleRoof"
	var gable := _box(Vector3(TEMPLE.size.x + 0.6, 1.6, TEMPLE.size.y * 0.6), Vector3(c.x, podium + 7.4, c.y), TILE.darkened(0.1))
	gable.name = "TempleGable"


## The basilica along the forum's north side: a long hall behind a
## colonnade, where the courts sit and the bankers keep their tables.
func _build_basilica() -> void:
	var c := BASILICA.get_center()
	_box(Vector3(BASILICA.size.x, 7.0, BASILICA.size.y - 3.0), Vector3(c.x, 3.5, c.y - 1.5), PLASTER.darkened(0.05))
	_solid(Vector3(BASILICA.size.x, 7.0, BASILICA.size.y - 3.0), Vector3(c.x, 3.5, c.y - 1.5))
	var x := BASILICA.position.x + 1.0
	while x <= BASILICA.end.x - 0.9:
		var column := _cylinder(0.35, 5.0, MARBLE)
		column.position = Vector3(x, 2.5, BASILICA.end.y - 0.8)
		_solid(Vector3(0.7, 5.0, 0.7), column.position)
		x += 3.0
	_box(Vector3(BASILICA.size.x, 0.6, 3.0), Vector3(c.x, 5.3, BASILICA.end.y - 1.0), TRAVERTINE)
	var roof := _box(Vector3(BASILICA.size.x + 0.6, 0.6, BASILICA.size.y), Vector3(c.x, 7.3, c.y), TILE)
	roof.name = "BasilicaRoof"


## The rostra: the speakers' platform, hung with the prows of captured ships,
## and an honorary column beside it.
func _build_rostra() -> void:
	var at := Vector3(FORUM.get_center().x - 6.0, 0, FORUM.position.y + 6.0)
	_box(Vector3(8.0, 1.8, 3.0), at + Vector3(0, 0.9, 0), TRAVERTINE)
	_solid(Vector3(8.0, 1.8, 3.0), at + Vector3(0, 0.9, 0))
	for i in 3:
		var prow := _box(Vector3(0.6, 0.6, 1.0), at + Vector3(-2.5 + i * 2.5, 1.0, 1.8), Color(0.5, 0.42, 0.26))
		prow.rotation.x = 0.5
	var column := _cylinder(0.6, 9.0, MARBLE)
	column.position = Vector3(FORUM.end.x - 6.0, 4.5, FORUM.end.y - 6.0)
	_solid(Vector3(1.2, 9.0, 1.2), column.position)


## Brick insulae, four and five storeys, packed along the Subura's alleys.
func _build_insulae() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1291
	var z := SUBURA.position.y + 3.0
	while z < SUBURA.end.y - 6.0:
		var x := SUBURA.position.x + 3.0
		while x < SUBURA.end.x - 7.0:
			var size := Vector3(rng.randf_range(7.0, 10.0), rng.randf_range(9.0, 13.0), rng.randf_range(6.0, 8.0))
			var at := Vector3(x + size.x / 2.0, size.y / 2.0, z + size.z / 2.0)
			_box(size, at, BRICK.darkened(rng.randf_range(0.0, 0.15)))
			_solid(size, at)
			# Shop fronts at street level and rows of windows above.
			_box(Vector3(size.x * 0.8, 2.2, 0.1), Vector3(at.x, 1.1, at.z + size.z / 2.0 + 0.05), Color(0.2, 0.15, 0.1))
			var floor_y := 3.5
			while floor_y < size.y - 1.0:
				_box(Vector3(size.x * 0.85, 0.7, 0.1), Vector3(at.x, floor_y, at.z + size.z / 2.0 + 0.05), Color(0.25, 0.2, 0.17))
				floor_y += 2.8
			var roof := _box(Vector3(size.x + 0.4, 0.4, size.z + 0.4), Vector3(at.x, size.y + 0.2, at.z), TILE)
			roof.name = "InsulaRoof%d" % get_child_count()
			x += size.x + 3.0
		z += 11.0


## Town houses (domus) along the streets west and south of the forum.
func _build_houses() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2753
	for spot in [Vector2(-628, 20), Vector2(-616, 30), Vector2(-628, 40), Vector2(-604, 22), Vector2(-616, -40), Vector2(-628, -52),
			Vector2(-606, -54), Vector2(-540, 2), Vector2(-525, 4), Vector2(-575, 30), Vector2(-575, 42)]:
		var size := Vector3(rng.randf_range(7.0, 9.0), 4.0, rng.randf_range(6.0, 8.0))
		var at := Vector3(spot.x, size.y / 2.0, spot.y)
		_box(size, at, PLASTER.darkened(rng.randf_range(0.0, 0.12)))
		_solid(size, at)
		_box(Vector3(1.4, 2.2, 0.1), Vector3(at.x, 1.1, at.z + size.z / 2.0 + 0.05), TIMBER)
		var roof := _box(Vector3(size.x + 0.6, 0.5, size.z + 0.6), Vector3(at.x, size.y + 0.25, at.z), TILE)
		roof.name = "HouseRoof%d" % get_child_count()


## The Circus Maximus: a sanded oval round a long spina (with turning posts
## at each end and an obelisk in the middle), tiered stands along the south
## straight, and a parapet along the north with a gap where the street
## comes in. Its racing line is CircusMaximus (circus_track.gd) in the scene.
func _build_circus() -> void:
	var centre := Vector3(CIRCUS.get_center().x, 0, CIRCUS.get_center().y)
	var spina := 16.0
	_box(Vector3(spina * 2.0, 1.0, 2.6), centre + Vector3(0, 0.5, 0), TRAVERTINE)
	_solid(Vector3(spina * 2.0, 1.0, 2.6), centre + Vector3(0, 0.5, 0))
	_box(Vector3(spina * 1.6, 0.1, 1.4), centre + Vector3(0, 1.05, 0), Color(0.35, 0.55, 0.62))
	for side in [-1.0, 1.0]:
		var base := centre + Vector3(side * (spina + 1.4), 0, 0)
		_box(Vector3(2.2, 0.8, 2.2), base + Vector3(0, 0.4, 0), TRAVERTINE.darkened(0.1))
		_solid(Vector3(2.2, 0.8, 2.2), base + Vector3(0, 0.4, 0))
		for offset in [-0.55, 0.0, 0.55]:
			var cone := _cylinder(0.3, 2.4, Color(0.78, 0.62, 0.28))
			(cone.mesh as CylinderMesh).top_radius = 0.05
			cone.position = base + Vector3(0, 2.0, offset)
	var obelisk := _cylinder(0.5, 9.0, Color(0.72, 0.52, 0.42))
	(obelisk.mesh as CylinderMesh).top_radius = 0.22
	(obelisk.mesh as CylinderMesh).radial_segments = 4
	obelisk.position = centre + Vector3(0, 5.5, 0)
	for tier in 4:
		var z := CIRCUS.end.y - 1.0 + tier * 1.2
		var size := Vector3(CIRCUS.size.x - 6.0, 0.8 + tier * 0.8, 1.2)
		_box(size, Vector3(centre.x, size.y / 2.0, z), TRAVERTINE.darkened(0.05 * tier))
		_solid(size, Vector3(centre.x, size.y / 2.0, z))
	for span in [[CIRCUS.position.x + 2.0, -560.0], [-552.0, CIRCUS.end.x - 2.0]]:
		var length: float = span[1] - span[0]
		var at := Vector3(span[0] + length / 2.0, 0.6, CIRCUS.position.y + 1.0)
		_box(Vector3(length, 1.2, 0.6), at, TRAVERTINE)
		_solid(Vector3(length, 1.2, 0.6), at)


## Cypresses and pines in the gardens, statues and lanterns in the forum,
## stalls and carts in the streets.
func _dress() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4410
	for n in 40:
		var p := Vector2(rng.randf_range(X_MIN + 6.0, X_MAX - 6.0), rng.randf_range(Z_MIN + 6.0, BANK - 4.0))
		if not _open_ground(p):
			continue
		var tree: Node3D = dresser.model("nature/" + ["tree_pineTallA", "tree_pineTallB", "tree_pineRoundC", "tree_pineTallC"][n % 4])
		tree.position = Vector3(p.x, height_at(p.x, p.y), p.y)
		tree.scale = Vector3.ONE * rng.randf_range(1.6, 2.4)
		add_child(tree)
	for spec in [["nature/statue_column", Vector3(FORUM.position.x + 8.0, 0, FORUM.end.y - 3.0), 3.2],
			["nature/statue_column", Vector3(FORUM.position.x + 30.0, 0, FORUM.end.y - 3.0), 3.2],
			["town/fountain-round", Vector3(FORUM.end.x - 10.0, 0, FORUM.position.y + 8.0), 2.2],
			["town/stall-red", Vector3(-586, 0, 20), 2.0], ["town/stall-green", Vector3(-594, 0, 30), 2.0],
			["town/cart", Vector3(-586, 0, 46), 2.0]]:
		var prop: Node3D = dresser.model(spec[0])
		prop.position = spec[1]
		prop.scale = Vector3.ONE * spec[2]
		add_child(prop)
	for x in [FORUM.position.x + 2.0, FORUM.end.x - 2.0]:
		for z in [FORUM.position.y + 2.0, FORUM.end.y - 2.0]:
			var lantern: Node3D = dresser.model("town/lantern")
			lantern.position = Vector3(x, 0, z)
			lantern.scale = Vector3.ONE * 2.0
			add_child(lantern)


func _open_ground(p: Vector2) -> bool:
	for rect in [FORUM.grow(3.0), TEMPLE.grow(4.0), BASILICA.grow(3.0), SUBURA.grow(2.0), CIRCUS.grow(2.0), QUAY.grow(4.0)]:
		if rect.has_point(p):
			return false
	return _street_distance(p) > 4.0


func _solid(size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	shape.position = at
	add_child(shape)


func _box(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
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


func _street_distance(p: Vector2) -> float:
	var best := INF
	for street in STREETS:
		for i in street.size() - 1:
			best = minf(best, Geometry2D.get_closest_point_to_segment(p, street[i], street[i + 1]).distance_to(p))
	return best


static func _rect_distance(rect: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(rect.position.x - p.x, 0.0), p.x - rect.end.x)
	var dz := maxf(maxf(rect.position.y - p.y, 0.0), p.y - rect.end.y)
	return Vector2(dx, dz).length()
