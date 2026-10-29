extends StaticBody3D
## A building spot in the villa: an outlined stone pad when empty. Built
## furniture appears as a working node of its own (a station, a bank chest,
## an altar, a farming patch, a waystone, or the steward at his desk)
## beside the pad's label.

const ContentDB := preload("res://scripts/content/content_db.gd")
const Station := preload("res://scripts/world/station.gd")
const Altar := preload("res://scripts/world/altar_node.gd")
const Patch := preload("res://scripts/world/patch_node.gd")
const Villa := preload("res://scripts/sim/villa.gd")
const NpcModel := preload("res://scripts/world/npc_model.gd")

## Unique per spot, e.g. "garden_1"; saves use it.
@export var hotspot_id := "hearth"
## The kind of spot, matching content: hearth, workbench, shrine, ...
@export var hotspot_type := "hearth"

var furniture := ""
var _pad: MeshInstance3D
var _label: Label3D
var _built: Node3D


func _init() -> void:
	collision_layer = 8
	add_to_group("villa_hotspots")


func _ready() -> void:
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(1.6, 0.1, 1.6)
	shape.position.y = 0.05
	add_child(shape)
	_pad = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.6, 0.05, 1.6)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.55, 0.52, 0.46, 0.6)
	stone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box.material = stone
	_pad.mesh = box
	_pad.position.y = 0.03
	add_child(_pad)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 28
	_label.outline_size = 8
	_label.position.y = 1.0
	_label.visibility_range_end = 30.0
	add_child(_label)
	show_furniture("")


func display_name() -> String:
	return ContentDB.hotspot(hotspot_type)["name"]


func examine_text() -> String:
	return ContentDB.hotspot(hotspot_type)["examine"]


## Shows the furniture ("" for an empty spot). Returns the working node, if any.
func show_furniture(furniture_id: String, patch_id := -1) -> Node3D:
	furniture = furniture_id
	if _built:
		_built.queue_free()
		_built = null
	_pad.visible = furniture.is_empty()
	_label.visible = furniture.is_empty()
	_label.text = "%s (build)" % display_name()
	if furniture.is_empty():
		return null
	var provides: Dictionary = ContentDB.furniture(furniture)["provides"]
	if provides.has("station"):
		var station := Station.new()
		station.kind = provides["station"]
		_built = station
	elif provides.has("altar"):
		var altar := Altar.new()
		altar.kind = provides["altar"]
		altar.title = "Lararium"
		_built = altar
	elif provides.has("patch"):
		var patch := Patch.new()
		patch.patch_type = provides["patch"]
		patch.patch_id = patch_id
		_built = patch
	elif provides.has("bank"):
		_built = _strongbox()
	elif provides.has("travel"):
		_built = _waystone()
	elif provides.has("comfort"):
		_built = _peristyle() if int(provides["comfort"]) >= 2 else _mosaic()
	elif provides.has("bath"):
		_built = _bath()
	elif provides.has("steward"):
		_built = _steward()
	add_child(_built)
	return _built


## A bank chest (Kenney's chest) that the bank menu recognises.
func _strongbox() -> Node3D:
	var chest := StaticBody3D.new()
	chest.collision_layer = 8
	chest.add_to_group("banks")
	chest.set_meta("examine", "Your own iron-bound strongbox. The same bank as everywhere.")
	var model: Node3D = load("res://assets/kenney/survival/chest.glb").instantiate()
	model.scale = Vector3.ONE * 3.6
	chest.add_child(model)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(1.0, 0.8, 1.4)
	shape.position.y = 0.4
	chest.add_child(shape)
	return chest


## A mosaic floor laid flush with the paving: a border, a meander band,
## and a rosette in the middle, in white marble and coloured stone.
## A bath house: a marble-rimmed pool of warm water under a tiled roof.
func _bath() -> Node3D:
	var bath := Node3D.new()
	var marble := StandardMaterial3D.new()
	marble.albedo_color = Color(0.9, 0.88, 0.82)
	for side in [[Vector3(4.4, 0.5, 0.3), Vector3(0, 0.25, -1.6)], [Vector3(4.4, 0.5, 0.3), Vector3(0, 0.25, 1.6)],
			[Vector3(0.3, 0.5, 3.5), Vector3(-2.2, 0.25, 0)], [Vector3(0.3, 0.5, 3.5), Vector3(2.2, 0.25, 0)]]:
		var rim := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = side[0]
		box.material = marble
		rim.mesh = box
		rim.position = side[1]
		bath.add_child(rim)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4.1, 3.0)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/water.gdshader")
	plane.material = material
	water.mesh = plane
	water.position.y = 0.4
	bath.add_child(water)
	var roof := MeshInstance3D.new()
	var tiles := BoxMesh.new()
	tiles.size = Vector3(5.2, 0.3, 4.4)
	var tile := StandardMaterial3D.new()
	tile.albedo_color = Color(0.62, 0.3, 0.2)
	tiles.material = tile
	roof.mesh = tiles
	roof.position.y = 3.2
	bath.add_child(roof)
	for corner in [Vector3(-2.3, 1.6, -1.9), Vector3(2.3, 1.6, -1.9), Vector3(-2.3, 1.6, 1.9), Vector3(2.3, 1.6, 1.9)]:
		var post := MeshInstance3D.new()
		var column := CylinderMesh.new()
		column.top_radius = 0.18
		column.bottom_radius = 0.2
		column.height = 3.2
		column.material = marble
		post.mesh = column
		post.position = corner
		bath.add_child(post)
	return bath


## A peristyle garden: a ring of columns round clipped box hedges and a
## fountain.
func _peristyle() -> Node3D:
	var garden := Node3D.new()
	var marble := StandardMaterial3D.new()
	marble.albedo_color = Color(0.92, 0.9, 0.86)
	var hedge := StandardMaterial3D.new()
	hedge.albedo_color = Color(0.25, 0.42, 0.2)
	for i in 10:
		var angle := TAU * i / 10.0
		var post := MeshInstance3D.new()
		var column := CylinderMesh.new()
		column.top_radius = 0.16
		column.bottom_radius = 0.18
		column.height = 2.8
		column.material = marble
		post.mesh = column
		post.position = Vector3(cos(angle) * 3.0, 1.4, sin(angle) * 3.0)
		garden.add_child(post)
	var box := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.2
	ring.outer_radius = 1.7
	ring.material = hedge
	box.mesh = ring
	box.position.y = 0.25
	garden.add_child(box)
	var fountain := MeshInstance3D.new()
	var basin := CylinderMesh.new()
	basin.top_radius = 0.6
	basin.bottom_radius = 0.7
	basin.height = 0.5
	basin.material = marble
	fountain.mesh = basin
	fountain.position.y = 0.25
	garden.add_child(fountain)
	return garden


func _mosaic() -> Node3D:
	var size := 48
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var white := Color(0.93, 0.91, 0.86)
	var dark := Color(0.2, 0.18, 0.2)
	var red := Color(0.62, 0.22, 0.16)
	var ochre := Color(0.8, 0.62, 0.3)
	for y in size:
		for x in size:
			var edge := mini(mini(x, y), mini(size - 1 - x, size - 1 - y))
			var color := white
			if edge < 2:
				color = dark
			elif edge < 6:
				# A key pattern round the border.
				color = dark if (x / 3 + y / 3) % 2 == 0 and edge > 2 else red
			else:
				var r := Vector2(x - size / 2.0, y - size / 2.0).length()
				var petal := absf(sin(atan2(y - size / 2.0, x - size / 2.0) * 4.0))
				if r < 4.0:
					color = ochre
				elif r < 6.0 + petal * 8.0:
					color = red if r > 4.0 + petal * 6.0 else ochre.lerp(white, 0.4)
				elif int(r) % 6 == 0:
					color = dark
			image.set_pixel(x, y, color)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.6
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4.0, 4.0)
	plane.material = material
	floor_mesh.mesh = plane
	floor_mesh.position.y = 0.03
	floor_mesh.set_meta("examine", "Your mosaic: a rosette in a meander border, every tessera cut by hand.")
	return floor_mesh


## The steward at a writing desk with his tablets; talk to him to collect
## what the presses made.
func _steward() -> Node3D:
	var steward := StaticBody3D.new()
	steward.collision_layer = 8
	steward.add_to_group("stewards")
	steward.set_meta("examine", "Your steward, a freedman with a good head for figures. He runs the presses while you're away.")
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.32, 0.2)
	var desk := MeshInstance3D.new()
	var top := BoxMesh.new()
	top.size = Vector3(1.4, 0.8, 0.7)
	top.material = wood
	desk.mesh = top
	desk.position = Vector3(0, 0.4, 0.3)
	steward.add_child(desk)
	# NpcModel stands its idle character 1 m below its parent.
	var figure := Node3D.new()
	figure.position = Vector3(0, 1.0, -0.4)
	steward.add_child(figure)
	var look: Node = NpcModel.new()
	look.scene = "adventurers/Rogue_Hooded"
	figure.add_child(look)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(1.4, 1.8, 1.4)
	shape.position.y = 0.9
	steward.add_child(shape)
	var label := Label3D.new()
	label.text = "Steward"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.outline_size = 8
	label.position.y = 2.3
	steward.add_child(label)
	return steward


## A carved milestone that sends you down the road to Portus Salis.
func _waystone() -> Node3D:
	var stone := StaticBody3D.new()
	stone.collision_layer = 8
	stone.add_to_group("waystones")
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.3
	cylinder.bottom_radius = 0.38
	cylinder.height = 1.6
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.68, 0.62)
	cylinder.material = material
	mesh.mesh = cylinder
	mesh.position.y = 0.8
	stone.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.shape = CylinderShape3D.new()
	shape.shape.radius = 0.38
	shape.shape.height = 1.6
	shape.position.y = 0.8
	stone.add_child(shape)
	var label := Label3D.new()
	label.text = "Waystone\n(Portus Salis)"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.outline_size = 8
	label.position.y = 2.0
	stone.add_child(label)
	return stone
