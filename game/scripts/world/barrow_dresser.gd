extends Node
## Dresses the barrow's greybox with CC0 KayKit Dungeon models at startup:
## stone wall pieces (some cracked or broken), tiled floors inside each
## room, decorated pillars, mounted torches at each light, and rubble,
## barrels, candles, and a chest. Collision and the navmesh are unchanged.

const DUNGEON := "res://assets/kaykit/dungeon/"
## Room floors in the barrow's local metres (matches the generated layout).
const ROOMS := [Rect2(-6, -6, 12, 12), Rect2(-2, -16, 4, 10), Rect2(-10, -32, 20, 16), Rect2(10, -30, 10, 4), Rect2(20, -38, 14, 20)]
const TILE := 4.0
const WALL_HEIGHT := 3.5
const WALL_VARIANTS := ["wall", "wall", "wall", "wall_cracked", "wall_broken"]
## Props in local metres: [model, position, rotation y, scale].
const PROPS := [
	["barrel_large", Vector3(-4.5, 0, -4.5), 0.0, 0.5], ["barrel_large", Vector3(-3.4, 0, -4.8), 0.6, 0.45],
	["chest", Vector3(4.2, 0, -4.6), -0.3, 0.6], ["rubble_half", Vector3(31.5, 0, -36.5), PI, 0.5],
	["rubble_half", Vector3(-8.8, 0, -30.5), 0.0, 0.45], ["candle_triple", Vector3(22.5, 0, -30.5), 0.0, 1.0],
	["candle_triple", Vector3(28.5, 0, -31.5), 0.7, 1.0], ["candle_triple", Vector3(0, 0, -30.6), 0.0, 1.0],
]

@export var barrow: Node3D

var _cache := {}


func _ready() -> void:
	_dress_floor()
	_dress_walls()
	_dress_pillars()
	_dress_torches()
	for prop in PROPS:
		var piece := _model(prop[0])
		piece.position = prop[1]
		piece.rotation.y = prop[2]
		piece.scale = Vector3.ONE * prop[3]
		barrow.add_child(piece)


func _model(name: String) -> Node3D:
	if not _cache.has(name):
		_cache[name] = load(DUNGEON + name + ".glb")
	return _cache[name].instantiate()


func _dress_floor() -> void:
	var floor_mesh := barrow.get_node_or_null("Floor/Mesh")
	if floor_mesh:
		floor_mesh.visible = false
	var root := Node3D.new()
	root.name = "FloorTiles"
	barrow.add_child(root)
	for room in ROOMS:
		var nx := ceili(room.size.x / TILE)
		var nz := ceili(room.size.y / TILE)
		for ix in nx:
			for iz in nz:
				var tile := _model("floor_tile_large_rocks" if (ix * 7 + iz * 3) % 5 == 0 else "floor_tile_large")
				var sx: float = room.size.x / nx / TILE
				var sz: float = room.size.y / nz / TILE
				tile.position = Vector3(room.position.x + (ix + 0.5) * room.size.x / nx, 0.0, room.position.y + (iz + 0.5) * room.size.y / nz)
				tile.scale = Vector3(sx, 1.0, sz)
				root.add_child(tile)


func _dress_walls() -> void:
	for wall in barrow.get_node("Walls").get_children():
		var size: Vector3 = (wall.get_node("Collision").shape as BoxShape3D).size
		wall.get_node("Mesh").visible = false
		var along_x := size.x >= size.z
		var length := size.x if along_x else size.z
		var count := maxi(1, roundi(length / TILE))
		var piece_length := length / count
		for i in count:
			var variant: String = WALL_VARIANTS[absi(hash("%s%d" % [wall.name, i])) % WALL_VARIANTS.size()]
			var piece := _model(variant)
			var offset := -length / 2.0 + piece_length * (i + 0.5)
			piece.position = Vector3(offset, -size.y / 2.0, 0) if along_x else Vector3(0, -size.y / 2.0, offset)
			piece.rotation.y = 0.0 if along_x else PI / 2.0
			piece.scale = Vector3(piece_length / TILE, WALL_HEIGHT / 4.0, (size.z if along_x else size.x) / 1.0)
			wall.add_child(piece)


func _dress_pillars() -> void:
	for pillar in barrow.get_node("Pillars").get_children():
		pillar.get_node("Mesh").visible = false
		var piece := _model("pillar_decorated")
		piece.position = Vector3(0, -WALL_HEIGHT / 2.0, 0)
		piece.scale = Vector3(0.55, WALL_HEIGHT / 4.0, 0.55)
		pillar.add_child(piece)


## Torches face into their room, away from the nearest wall.
func _dress_torches() -> void:
	for torch in barrow.get_node("Torches").get_children():
		var flame := torch.get_node_or_null("Flame")
		if flame:
			flame.visible = false
		var room := _room_of(Vector2(torch.position.x, torch.position.z))
		var centre := room.get_center()
		var piece := _model("torch_mounted")
		piece.scale = Vector3.ONE * 1.3
		var to_centre := Vector2(centre.x - torch.position.x, centre.y - torch.position.z)
		piece.rotation.y = atan2(to_centre.x, to_centre.y)
		piece.position = Vector3(0, -0.6, 0)
		torch.add_child(piece)


func _room_of(point: Vector2) -> Rect2:
	for room in ROOMS:
		if room.grow(1.0).has_point(point):
			return room
	return ROOMS[0]
