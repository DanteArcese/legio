extends StaticBody3D
## The circus, east of the fort (x around 320, z around 160): a sanded oval
## track round a long spina with turning posts and an obelisk, stands
## along both straights, and hills beyond the walls. Built at startup in
## the overworld's low-poly style. During a race it also drives the rival
## chariots round the racing line.

const Circus := preload("res://scripts/sim/circus.gd")
const ChariotModel := preload("res://scripts/world/chariot_model.gd")
const KaykitCharacter := preload("res://scripts/world/kaykit_character.gd")

const X_MIN := 262.0
const X_MAX := 378.0
const Z_MIN := 120.0
const Z_MAX := 200.0
const PAD := 25.0
const CELL := 1.0
const CENTER := Vector3(320, 0, 160)
## The racing line: straights this far either side of the centre, turns of
## this radius. The sand runs a few metres either side of it.
const HALF := 30.0
const RADIUS := 12.0
const SAND_INNER := 6.5
const SAND_OUTER := 17.5
const SPINA_HALF := 26.0
## The munera are fought on the sand past the east turning post.
const ARENA := Vector3(356, 0, 160)

const GRASS := Color(0.48, 0.6, 0.3)
const GRASS_LIGHT := Color(0.55, 0.65, 0.34)
const SAND := Color(0.86, 0.76, 0.56)
const STONE := Color(0.8, 0.76, 0.68)
const MARBLE := Color(0.93, 0.91, 0.86)

@export var driver: Node
@export var player_entity: Node

var _noise := FastNoiseLite.new()
## Rival chariots during a race: [{"node", "speed", "lane", "s"}].
var _rivals := []
var _race_start := -1


func _init() -> void:
	collision_layer = 1
	add_to_group("navigation_source")
	add_to_group("circus")


func _ready() -> void:
	_noise.seed = 77
	_noise.frequency = 0.05
	_build_ground()
	_build_spina()
	_build_stands()
	_build_walls()
	if driver:
		driver.sim_event.connect(_on_sim_event)


func height_at(x: float, z: float) -> float:
	if x > X_MIN and x < X_MAX and z > Z_MIN and z < Z_MAX:
		return 0.0
	var dx := maxf(maxf(X_MIN - x, x - X_MAX), 0.0)
	var dz := maxf(maxf(Z_MIN - z, z - Z_MAX), 0.0)
	return smoothstep(0.0, PAD, maxf(dx, dz)) * 8.0 + _noise.get_noise_2d(x, z) * 1.2


## Distance from a point to the racing line's oval.
static func oval_distance(x: float, z: float) -> float:
	var dx := absf(x - CENTER.x)
	var dz := z - CENTER.z
	if dx <= HALF:
		return absf(absf(dz) - RADIUS)
	return absf(Vector2(dx - HALF, dz).length() - RADIUS)


func color_at(x: float, z: float) -> Color:
	var inside := x > X_MIN and x < X_MAX and z > Z_MIN and z < Z_MAX
	if inside:
		var dx := absf(x - CENTER.x)
		var dz := z - CENTER.z
		var from_axis := absf(dz) if dx <= HALF else Vector2(dx - HALF, dz).length()
		if from_axis > SAND_INNER and from_axis < SAND_OUTER:
			return SAND.darkened(0.08) if absf(x - CENTER.x) < 0.6 and dz > 0.0 else SAND
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


## The spina down the middle: a long low wall with a water basin along its
## top, three-cone turning posts (metae) at each end, and an obelisk.
func _build_spina() -> void:
	_solid(Vector3(SPINA_HALF * 2.0, 1.0, 3.0), CENTER + Vector3(0, 0.5, 0), STONE)
	_visual(Vector3(SPINA_HALF * 1.6, 0.12, 1.6), CENTER + Vector3(0, 1.06, 0), Color(0.35, 0.55, 0.62))
	for side in [-1.0, 1.0]:
		var base := CENTER + Vector3(side * (SPINA_HALF + 1.5), 0, 0)
		_solid(Vector3(2.2, 0.8, 2.2), base + Vector3(0, 0.4, 0), STONE)
		for offset in [-0.55, 0.0, 0.55]:
			var cone := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.05
			mesh.bottom_radius = 0.32
			mesh.height = 2.2
			mesh.material = _material(Color(0.78, 0.62, 0.28))
			cone.mesh = mesh
			cone.position = base + Vector3(0, 1.9, offset)
			add_child(cone)
	var obelisk := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.25
	shaft.bottom_radius = 0.55
	shaft.height = 7.0
	shaft.radial_segments = 4
	shaft.material = _material(Color(0.72, 0.52, 0.42))
	obelisk.mesh = shaft
	obelisk.position = CENTER + Vector3(0, 4.5, 0)
	obelisk.rotation.y = PI / 4.0
	add_child(obelisk)


## Stepped stands of stone seating along both straights, behind a parapet.
func _build_stands() -> void:
	for side in [-1.0, 1.0]:
		var front: float = CENTER.z + side * (SAND_OUTER + 2.5)
		_solid(Vector3(HALF * 2.0 + 10.0, 1.0, 0.4), Vector3(CENTER.x, 0.5, front), STONE)
		for row in 4:
			var depth := 1.4
			var z: float = front + side * (0.9 + row * depth)
			_solid(Vector3(HALF * 2.0 + 10.0, 1.0 + row * 0.7, depth), Vector3(CENTER.x, (1.0 + row * 0.7) / 2.0, z), MARBLE.darkened(row * 0.04))


## A wall round the whole circus, open at the west end for the road.
func _build_walls() -> void:
	var height := 2.4
	var gap := 4.0
	var mid_z := (Z_MIN + Z_MAX) / 2.0
	var spans := [
		[Vector3((X_MIN + X_MAX) / 2.0, 0, Z_MIN), Vector3(X_MAX - X_MIN, height, 0.5)],
		[Vector3((X_MIN + X_MAX) / 2.0, 0, Z_MAX), Vector3(X_MAX - X_MIN, height, 0.5)],
		[Vector3(X_MAX, 0, mid_z), Vector3(0.5, height, Z_MAX - Z_MIN)],
		[Vector3(X_MIN, 0, (Z_MIN + mid_z - gap) / 2.0), Vector3(0.5, height, mid_z - gap - Z_MIN)],
		[Vector3(X_MIN, 0, (Z_MAX + mid_z + gap) / 2.0), Vector3(0.5, height, Z_MAX - mid_z - gap)],
	]
	for span in spans:
		var size: Vector3 = span[1]
		_solid(size, span[0] + Vector3(0, size.y / 2.0, 0), STONE.darkened(0.1))


func _solid(size: Vector3, at: Vector3, color: Color) -> void:
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	shape.position = at
	add_child(shape)
	_visual(size, at, color)


func _visual(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = _material(color)
	mesh.mesh = box
	mesh.position = at
	add_child(mesh)
	return mesh


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material


func _on_sim_event(event: Dictionary) -> void:
	if player_entity == null or event.get("id") != player_entity.entity_id:
		return
	match event["type"]:
		"race_started":
			_spawn_rivals(event["start"])
		"race_ended":
			_clear_rivals()


func _spawn_rivals(start: int) -> void:
	_clear_rivals()
	_race_start = start
	var rivals: Array = Circus.data()["rivals"]
	for i in rivals.size():
		var rival: Dictionary = rivals[i]
		var node := Node3D.new()
		node.name = "Rival%d" % i
		node.add_child(ChariotModel.build(Color(rival["color"])))
		var figure := KaykitCharacter.create({"scene": "adventurers/Rogue"})
		figure.position.y = 0.45
		node.add_child(figure)
		var label := Label3D.new()
		label.text = String(rival["name"]).capitalize()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 32
		label.outline_size = 8
		label.position.y = 2.6
		node.add_child(label)
		add_child(node)
		var lane := Circus.LANE_WIDTH * (-1.0 if i % 2 == 0 else 1.0) * (1 + i / 2)
		_rivals.append({"node": node, "speed": rival["speed"], "lane": lane, "figure": figure})
	_place_rivals()


func _clear_rivals() -> void:
	for rival in _rivals:
		rival["node"].queue_free()
	_rivals.clear()
	_race_start = -1


func _process(_delta: float) -> void:
	if not _rivals.is_empty():
		_place_rivals()


## Rivals hold their pace on their lane from the start tick, smoothed
## between ticks.
func _place_rivals() -> void:
	var sim: RefCounted = driver.sim
	var ticks := maxf(0.0, sim.tick - _race_start + driver.clock.progress())
	var track: Dictionary = sim.circus.track
	var finish_s: float = Circus.START_PROGRESS + Circus.data()["laps"] * Circus.lap_length(track)
	for rival in _rivals:
		var s: float = minf(Circus.START_PROGRESS + rival["speed"] * ticks * Circus.TICK_SECONDS, finish_s)
		var here := Circus.point_at(track, s, rival["lane"])
		var ahead := Circus.point_at(track, s + 1.0, rival["lane"])
		var node: Node3D = rival["node"]
		node.position = here - global_position
		node.look_at(ahead, Vector3.UP)
		rival["figure"].animate(0.0, 0.0)
