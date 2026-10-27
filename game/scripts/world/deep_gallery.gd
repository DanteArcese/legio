extends StaticBody3D
## The deep gallery under Vipasca: a winding mine tunnel cut through red
## rock, built at startup on a 1 m grid. Walkable cells come from the tunnel
## polyline, a side alcove with silver and gold, and a round chamber at the
## far end. Every walkable cell gets floor; every cell beside one gets a
## rough rock pillar of wall. Timber frames prop the roof along the way,
## and mounted torches light it.
##
## It lies in the underground band (see area_lighting.gd), far from the
## barrow, at x around 180 and z around 400, and is reached through the
## gallery mouth at Vipasca once The Silent Gallery is done.

const DUNGEON := "res://assets/kaykit/dungeon/"
## The tunnel as a 2D polyline (x, z), from the stairs up to the chamber.
const TUNNEL := [Vector2(165, 368), Vector2(167, 384), Vector2(177, 394), Vector2(180, 409), Vector2(182, 416)]
const TUNNEL_HALF_WIDTH := 2.3
const ALCOVE_PATH := [Vector2(177, 394), Vector2(189, 391)]
const ALCOVE := Vector2(193, 391)
const ALCOVE_RADIUS := 4.5
const CHAMBER := Vector2(182, 426)
const CHAMBER_RADIUS := 11.0
## The cells the gallery spans (with a wall's margin).
const BOUNDS := Rect2(156, 362, 48, 78)
const WALL_HEIGHT := 3.6
const TIMBER_SPACING := 6.0

const ROCK := Color(0.45, 0.25, 0.18)
const ROCK_DARK := Color(0.33, 0.18, 0.13)
const FLOOR := Color(0.42, 0.3, 0.24)
const FLOOR_DARK := Color(0.34, 0.24, 0.19)
const TIMBER := Color(0.38, 0.27, 0.17)

var _noise := FastNoiseLite.new()
var _walkable := {}


func _init() -> void:
	collision_layer = 1
	add_to_group("navigation_source")


func _ready() -> void:
	_noise.seed = 913
	_noise.frequency = 0.3
	_mark_walkable()
	_build_floor()
	_build_walls()
	_build_timbers()
	_build_torches()


## Whether a point is open floor: inside the tunnel, alcove or chamber.
func is_open(p: Vector2) -> bool:
	if _polyline_distance(p, TUNNEL) <= TUNNEL_HALF_WIDTH:
		return true
	if _polyline_distance(p, ALCOVE_PATH) <= 1.6 or p.distance_to(ALCOVE) <= ALCOVE_RADIUS:
		return true
	return p.distance_to(CHAMBER) <= CHAMBER_RADIUS


func _mark_walkable() -> void:
	for x in range(int(BOUNDS.position.x), int(BOUNDS.end.x)):
		for z in range(int(BOUNDS.position.y), int(BOUNDS.end.y)):
			if is_open(Vector2(x + 0.5, z + 0.5)):
				_walkable[Vector2i(x, z)] = true


func _build_floor() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: Vector2i in _walkable:
		var shade := _noise.get_noise_2d(cell.x, cell.y) * 0.5 + 0.5
		tool.set_color(FLOOR_DARK.lerp(FLOOR, shade))
		var corners := [Vector3(cell.x, 0, cell.y), Vector3(cell.x + 1, 0, cell.y), Vector3(cell.x + 1, 0, cell.y + 1), Vector3(cell.x, 0, cell.y + 1)]
		for index in [0, 1, 2, 0, 2, 3]:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(corners[index])
	var mesh := tool.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = "Floor"
	instance.mesh = mesh
	add_child(instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BOUNDS.size.x, 1.0, BOUNDS.size.y)
	shape.shape = box
	shape.position = Vector3(BOUNDS.get_center().x, -0.5, BOUNDS.get_center().y)
	add_child(shape)


## A rough rock block on every cell next to open floor: one multimesh for
## the look, and one collision box per block.
func _build_walls() -> void:
	var edge := {}
	for cell: Vector2i in _walkable:
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			if not _walkable.has(cell + offset):
				edge[cell + offset] = true
	var cells := edge.keys()
	var blocks := MultiMesh.new()
	blocks.transform_format = MultiMesh.TRANSFORM_3D
	blocks.use_colors = true
	var box := BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	box.material = material
	blocks.mesh = box
	blocks.instance_count = cells.size()
	for i in cells.size():
		var cell: Vector2i = cells[i]
		var jitter := _noise.get_noise_2d(cell.x * 3.1, cell.y * 3.1)
		var height := WALL_HEIGHT + jitter * 1.2
		var size := Vector3(1.25 + jitter * 0.2, height, 1.25 - jitter * 0.2)
		var basis := Basis.from_euler(Vector3(jitter * 0.12, jitter * 2.0, -jitter * 0.1)).scaled(size)
		blocks.set_instance_transform(i, Transform3D(basis, Vector3(cell.x + 0.5, height / 2.0, cell.y + 0.5)))
		blocks.set_instance_color(i, ROCK_DARK.lerp(ROCK, jitter * 0.5 + 0.5))
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = Vector3(1.0, WALL_HEIGHT, 1.0)
		shape.position = Vector3(cell.x + 0.5, WALL_HEIGHT / 2.0, cell.y + 0.5)
		add_child(shape)
	var instance := MultiMeshInstance3D.new()
	instance.name = "Walls"
	instance.multimesh = blocks
	add_child(instance)


## Timber frames across the tunnel: two posts and a lintel, square to it.
func _build_timbers() -> void:
	var travelled := 0.0
	for i in TUNNEL.size() - 1:
		var a: Vector2 = TUNNEL[i]
		var b: Vector2 = TUNNEL[i + 1]
		var length := a.distance_to(b)
		var along := (b - a).normalized()
		var across := Vector2(-along.y, along.x)
		var t := fmod(TIMBER_SPACING - fmod(travelled, TIMBER_SPACING), TIMBER_SPACING)
		while t < length:
			var at := a + along * t
			var frame := Node3D.new()
			frame.name = "Timber%d" % get_child_count()
			frame.position = Vector3(at.x, 0, at.y)
			frame.rotation.y = atan2(across.x, across.y)
			add_child(frame)
			for side in [-1.0, 1.0]:
				_box(frame, Vector3(0.25, 2.9, 0.25), Vector3(0, 1.45, side * (TUNNEL_HALF_WIDTH - 0.3)), TIMBER)
			_box(frame, Vector3(0.3, 0.3, TUNNEL_HALF_WIDTH * 2.0), Vector3(0, 2.95, 0), TIMBER.darkened(0.15))
			t += TIMBER_SPACING
		travelled += length


## Mounted torches with warm light along the tunnel walls, in the alcove,
## and round the chamber.
func _build_torches() -> void:
	var spots := []
	for i in range(1, TUNNEL.size()):
		var a: Vector2 = TUNNEL[i - 1]
		var b: Vector2 = TUNNEL[i]
		var mid := (a + b) / 2.0
		var along := (b - a).normalized()
		spots.append([mid + Vector2(-along.y, along.x) * (TUNNEL_HALF_WIDTH - 0.2), Vector2(along.y, -along.x)])
	spots.append([ALCOVE + Vector2(ALCOVE_RADIUS - 0.4, 0), Vector2(-1, 0)])
	for k in 5:
		var angle := TAU * k / 5.0 + 0.4
		var dir := Vector2(cos(angle), sin(angle))
		spots.append([CHAMBER + dir * (CHAMBER_RADIUS - 0.4), -dir])
	for spot in spots:
		var light := OmniLight3D.new()
		light.light_color = Color(1, 0.65, 0.35)
		light.light_energy = 2.4
		light.omni_range = 10.0
		light.position = Vector3(spot[0].x, 2.4, spot[0].y)
		add_child(light)
		var torch: Node3D = load(DUNGEON + "torch_mounted.glb").instantiate()
		torch.scale = Vector3.ONE * 1.3
		torch.position = Vector3(0, -0.6, 0)
		torch.rotation.y = atan2(spot[1].x, spot[1].y)
		light.add_child(torch)


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


static func _polyline_distance(p: Vector2, line: Array) -> float:
	var best := INF
	for i in line.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1]).distance_to(p))
	return best
