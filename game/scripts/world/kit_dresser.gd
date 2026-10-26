extends Node
## Dresses the greybox town with CC0 Kenney models at startup.
##
## Collision, the navmesh, and the layout all stay as they are: placeholder
## meshes are hidden and kit models are added as children of the same
## bodies (so occlusion fading still applies). Roofs become gabled tile
## roofs in their "<Building>Roof" nodes, so the hide-roofs toggle still works.
## Scenery (bushes, rocks, flowers) is scattered with a fixed seed.

const KIT := "res://assets/kenney/"
const TREES := ["tree_pineTallA", "tree_pineTallB", "tree_pineTallC", "tree_pineDefaultA",
	"tree_pineDefaultB", "tree_pineRoundC", "tree_default", "tree_oak", "tree_fat", "tree_detailed"]
const TREE_MODEL_HEIGHT := 1.6
const SCATTER := [
	["plant_bush", 70, 2.2], ["plant_bushLarge", 40, 2.4], ["plant_bushDetailed", 30, 2.2],
	["plant_flatTall", 30, 2.0], ["flower_redA", 40, 2.0], ["flower_yellowA", 40, 2.0],
	["mushroom_red", 15, 2.0], ["mushroom_tanGroup", 15, 2.0], ["log", 10, 2.4],
	["stump_round", 12, 2.4], ["rock_smallA", 25, 2.0], ["rock_largeA", 14, 2.2], ["stone_largeA", 10, 2.0],
]
## Which side each building's door faces.
const DOOR_SIDES := {"Bank": "+z", "Smithy": "+z", "Granary": "-x", "HouseA": "-z", "HouseB": "-z", "HouseC": "-z"}
const WALL_TILE := 2.6
const ROOF_COLOR := Color(0.7, 0.33, 0.22)
const ROOF_OVERHANG := 0.35
## Nature kit materials recoloured by name, from its teal palette to a
## natural one.
const NATURE_COLORS := {
	"leafsDark": Color(0.2, 0.4, 0.17), "leafsGreen": Color(0.3, 0.52, 0.21), "leafs": Color(0.3, 0.52, 0.21),
	"grass": Color(0.36, 0.58, 0.24), "woodBarkDark": Color(0.33, 0.22, 0.14), "woodBark": Color(0.45, 0.31, 0.19),
	"wood": Color(0.5, 0.36, 0.22), "dirt": Color(0.5, 0.41, 0.3), "stoneDark": Color(0.5, 0.49, 0.46),
	"stone": Color(0.7, 0.68, 0.63),
}
const FORT_TILE := 2.5
const FORT_WALL_HEIGHT := 3.0

@export var town: Node3D
@export var terrain: Node

var _cache := {}
var _materials := {}
var _town_palette: ImageTexture


func _ready() -> void:
	_dress_fort()
	_dress_buildings()
	_dress_trees()
	_dress_choppable_trees()
	_dress_stalls()
	_dress_banks()
	_dress_forum()
	_scatter_scenery()
	_fence_fields()


func model(path: String) -> Node3D:
	if not _cache.has(path):
		_cache[path] = load(KIT + path + ".glb")
	var instance: Node3D = _cache[path].instantiate()
	if path.begins_with("nature/"):
		_recolor(instance, _nature_material)
	elif path.begins_with("town/"):
		_recolor(instance, _town_material)
	return instance


func _recolor(node: Node, convert: Callable) -> void:
	for mesh_instance in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mesh_instance.mesh
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i) as StandardMaterial3D
			if material:
				mesh_instance.set_surface_override_material(i, convert.call(material))


func _nature_material(material: StandardMaterial3D) -> StandardMaterial3D:
	var key := material.resource_name
	if not _materials.has(key):
		var copy := material.duplicate() as StandardMaterial3D
		for prefix in NATURE_COLORS:
			if key.begins_with(prefix):
				copy.albedo_color = NATURE_COLORS[prefix]
				break
		_materials[key] = copy
	return _materials[key]


## The town kit's palette texture with its lavender stone and plaster
## turned into warm Roman cream and ochre.
func _town_material(material: StandardMaterial3D) -> StandardMaterial3D:
	var key := "town:" + material.resource_name
	if not _materials.has(key):
		var copy := material.duplicate() as StandardMaterial3D
		if copy.albedo_texture:
			if _town_palette == null:
				_town_palette = ImageTexture.create_from_image(_warm_palette(copy.albedo_texture.get_image()))
			copy.albedo_texture = _town_palette
		_materials[key] = copy
	return _materials[key]


static func _warm_palette(source: Image) -> Image:
	var image := source.duplicate() as Image
	if image.is_compressed():
		image.decompress()
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			# Lavender / blue-grey: hue 0.6-0.8, low to mid saturation.
			if c.h > 0.58 and c.h < 0.82 and c.s < 0.45:
				image.set_pixel(x, y, Color.from_hsv(0.1, 0.22 + c.s * 0.2, minf(c.v * 1.05, 0.97), c.a))
	return image


# --- Fort ------------------------------------------------------------------

func _dress_fort() -> void:
	for wall in town.get_node("Walls").get_children():
		if not wall is StaticBody3D:
			continue
		var size: Vector3 = (wall.get_node("Collision").shape as BoxShape3D).size
		_hide_mesh(wall)
		if String(wall.name).begins_with("Tower"):
			_build_tower(wall, size)
		else:
			_build_wall_run(wall, size)


func _build_wall_run(wall: StaticBody3D, size: Vector3) -> void:
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	var count := maxi(1, roundi(length / FORT_TILE))
	var tile := length / count
	for i in count:
		var piece := model("castle/wall")
		var offset := -length / 2.0 + tile * (i + 0.5)
		piece.position = Vector3(offset, -size.y / 2.0, 0) if along_x else Vector3(0, -size.y / 2.0, offset)
		piece.rotation.y = 0.0 if along_x else PI / 2.0
		piece.scale = Vector3(tile, FORT_WALL_HEIGHT / 1.31, size.z if along_x else size.x)
		wall.add_child(piece)


func _build_tower(tower: StaticBody3D, size: Vector3) -> void:
	var width := size.x
	var y := -size.y / 2.0
	for part in ["castle/tower-square-base", "castle/tower-square-mid", "castle/tower-square-top"]:
		var piece := model(part)
		piece.position = Vector3(0, y, 0)
		piece.scale = Vector3(width, width, width)
		tower.add_child(piece)
		y += width * (1.0 if part != "castle/tower-square-top" else 0.3)
	var flag := model("castle/flag")
	flag.position = Vector3(0, y, 0)
	flag.scale = Vector3.ONE * width
	tower.add_child(flag)


# --- Buildings ---------------------------------------------------------------

func _dress_buildings() -> void:
	var buildings := town.get_node("Buildings")
	for name in DOOR_SIDES:
		var body: StaticBody3D = buildings.get_node_or_null(name)
		if body == null:
			continue
		var size: Vector3 = (body.get_node("Collision").shape as BoxShape3D).size
		_hide_mesh(body)
		_build_walls(body, size, DOOR_SIDES[name])
		var roof: MeshInstance3D = buildings.get_node_or_null(name + "Roof")
		if roof:
			roof.mesh = _gable_roof(size.x + ROOF_OVERHANG * 2.0, size.z + ROOF_OVERHANG * 2.0)
			roof.position = body.position + Vector3(0, size.y / 2.0, 0)


## Wall panels around a box footprint: a door in the middle of the door
## side, shuttered windows elsewhere. Panels sit on the +x edge of a tile,
## so each side rotates its tiles to face outward.
func _build_walls(body: StaticBody3D, size: Vector3, door_side: String) -> void:
	var sides := {
		"+x": [size.z, 0.0, Vector3(1, 0, 0), Vector3(0, 0, 1)],
		"-x": [size.z, PI, Vector3(-1, 0, 0), Vector3(0, 0, 1)],
		"+z": [size.x, -PI / 2.0, Vector3(0, 0, 1), Vector3(1, 0, 0)],
		"-z": [size.x, PI / 2.0, Vector3(0, 0, -1), Vector3(1, 0, 0)],
	}
	for side in sides:
		var length: float = sides[side][0]
		var count := maxi(1, roundi(length / WALL_TILE))
		var tile := length / count
		var outward: Vector3 = sides[side][2]
		var along: Vector3 = sides[side][3]
		var half_depth := (size.x if side.ends_with("x") else size.z) / 2.0
		for i in count:
			var kind := "town/wall-window-shutters" if i % 2 == 0 else "town/wall"
			if side == door_side and i == count / 2:
				kind = "town/wall-door"
			var piece := model(kind)
			var centre := outward * (half_depth - tile / 2.0) + along * (-length / 2.0 + tile * (i + 0.5))
			piece.position = centre + Vector3(0, -size.y / 2.0, 0)
			piece.rotation.y = sides[side][1]
			piece.scale = Vector3(tile, size.y, tile)
			body.add_child(piece)


## A terracotta gabled roof, ridge along the longer side, flat-shaded.
func _gable_roof(width: float, depth: float) -> ArrayMesh:
	var along_x := width >= depth
	var half_long := (width if along_x else depth) / 2.0
	var half_short := (depth if along_x else width) / 2.0
	var ridge := half_short * 0.75
	var p := func(long: float, up: float, short: float) -> Vector3:
		return Vector3(long, up, short) if along_x else Vector3(short, up, long)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	tool.set_color(ROOF_COLOR)
	var quads := [
		[p.call(-half_long, 0, -half_short), p.call(half_long, 0, -half_short), p.call(half_long, ridge, 0), p.call(-half_long, ridge, 0)],
		[p.call(half_long, 0, half_short), p.call(-half_long, 0, half_short), p.call(-half_long, ridge, 0), p.call(half_long, ridge, 0)],
	]
	for quad in quads:
		for index in [0, 1, 2, 0, 2, 3]:
			tool.add_vertex(quad[index])
	tool.set_color(ROOF_COLOR.darkened(0.15))
	for end in [-half_long, half_long]:
		var tri := [p.call(end, 0, -half_short), p.call(end, ridge, 0), p.call(end, 0, half_short)]
		if end > 0:
			tri.reverse()
		for vertex in tri:
			tool.add_vertex(vertex)
	tool.generate_normals()
	var mesh := tool.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	mesh.surface_set_material(0, material)
	return mesh


# --- Trees, forum, scenery ---------------------------------------------------------

func _dress_trees() -> void:
	for tree in town.get_node("Outside/Woods").get_children():
		var trunk: MeshInstance3D = tree.get_node_or_null("Trunk")
		if trunk == null:
			continue
		var height: float = (trunk.mesh as CylinderMesh).height * 2.0
		trunk.visible = false
		tree.get_node("Leaves").visible = false
		var choice: String = TREES[absi(hash(String(tree.name))) % TREES.size()]
		var instance := model("nature/" + choice)
		instance.scale = Vector3.ONE * (height / TREE_MODEL_HEIGHT) * 1.15
		instance.rotation.y = float(absi(hash(String(tree.name) + "r")) % 360) * PI / 180.0
		tree.add_child(instance)


## Bank chests get Kenney's Survival Kit chest (the box stays for collision).
func _dress_banks() -> void:
	for bank in get_tree().get_nodes_in_group("banks"):
		var box: Node3D = bank.get_node_or_null("Mesh")
		if box == null:
			continue
		box.visible = false
		var chest: Node3D = load("res://assets/kenney/survival/chest.glb").instantiate()
		chest.scale = Vector3.ONE * 3.6
		chest.position.y = -0.45 + 0.045 * 3.6
		bank.add_child(chest)


## Market stalls (the thieving targets in the forum).
func _dress_stalls() -> void:
	for stall in get_tree().get_nodes_in_group("stalls"):
		var prop := model("town/" + stall.model_name())
		prop.scale = Vector3.ONE * 2.0
		stall.dress(prop)


## Choppable trees get their Kenney model and a stump for when they fall.
func _dress_choppable_trees() -> void:
	for tree in get_tree().get_nodes_in_group("trees"):
		var stump := model("nature/stump_round")
		stump.scale = Vector3.ONE * 3.0
		tree.dress(model("nature/" + tree.model_name()), stump)


func _dress_forum() -> void:
	var buildings := town.get_node("Buildings")
	var column: MeshInstance3D = buildings.get_node_or_null("StatueColumn")
	if column:
		column.visible = false
		var statue := model("nature/statue_column")
		statue.position = Vector3(column.position.x, 0.6, column.position.z)
		statue.scale = Vector3.ONE * 3.4
		buildings.add_child(statue)
	for spec in [["town/cart", Vector3(10.8, 0, 2.0), 0.4]]:
		var prop := model(spec[0])
		prop.position = spec[1]
		prop.rotation.y = spec[2]
		prop.scale = Vector3.ONE * 2.0
		town.add_child(prop)


func _scatter_scenery() -> void:
	if terrain == null:
		return
	var root := Node3D.new()
	root.name = "Scenery"
	town.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for spec in SCATTER:
		var placed := 0
		var attempts := 0
		while placed < spec[1] and attempts < spec[1] * 20:
			attempts += 1
			var x := rng.randf_range(-60.0, 60.0)
			var z := rng.randf_range(-60.0, 60.0)
			if not terrain.is_grassy(x, z) or terrain.level_weight(Vector2(x, z)) > 0.5:
				continue
			var prop := model("nature/" + spec[0])
			prop.position = Vector3(x, terrain.height_at(x, z), z)
			prop.rotation.y = rng.randf_range(0.0, TAU)
			prop.scale = Vector3.ONE * spec[2] * rng.randf_range(0.8, 1.25)
			root.add_child(prop)
			placed += 1


## Wooden fences around each field, with a gate in the middle of one side.
func _fence_fields() -> void:
	if terrain == null:
		return
	var root := Node3D.new()
	root.name = "FieldFences"
	town.add_child(root)
	for field in terrain.FIELDS:
		var rect: Rect2 = field.grow(0.4)
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for side in 4:
			var a: Vector2 = corners[side]
			var b: Vector2 = corners[(side + 1) % 4]
			var length := a.distance_to(b)
			var count := maxi(1, roundi(length / 1.5))
			for i in count:
				var t := (i + 0.5) / count
				var point := a.lerp(b, t)
				var gate := side == 0 and i == count / 2
				var piece := model("town/fence-gate" if gate else "town/fence")
				piece.position = Vector3(point.x, 0, point.y)
				# Fence panels run along local z; turn them to follow the side.
				piece.rotation.y = atan2(b.x - a.x, b.y - a.y)
				piece.scale = Vector3(1.5, 1.5, length / count)
				root.add_child(piece)


func _hide_mesh(body: Node) -> void:
	var mesh := body.get_node_or_null("Mesh")
	if mesh:
		mesh.visible = false
