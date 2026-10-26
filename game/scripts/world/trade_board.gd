extends StaticBody3D
## A trade board for Mercatura contracts: a wooden board on two posts,
## covered in wax tablets.

const ContentDB := preload("res://scripts/content/content_db.gd")
const WOOD := Color(0.45, 0.33, 0.22)

@export var board_id := "forum_board"


func _init() -> void:
	collision_layer = 8
	add_to_group("trade_boards")
	add_to_group("navigation_source")


func _ready() -> void:
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(1.6, 2.0, 0.3)
	shape.position.y = 1.0
	add_child(shape)
	for x in [-0.7, 0.7]:
		_box(Vector3(0.12, 2.0, 0.12), Vector3(x, 1.0, 0), WOOD.darkened(0.2))
	_box(Vector3(1.6, 0.9, 0.08), Vector3(0, 1.45, 0), WOOD)
	var tablet := Color(0.85, 0.78, 0.55)
	for i in 6:
		_box(Vector3(0.34, 0.22, 0.02), Vector3(-0.5 + (i % 3) * 0.5, 1.25 + (i / 3) * 0.38, 0.06), tablet.darkened(0.1 * (i % 2)))
	var label := Label3D.new()
	label.text = display_name()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.outline_size = 8
	label.position.y = 2.4
	label.visibility_range_end = 30.0
	add_child(label)


func display_name() -> String:
	return ContentDB.board(board_id)["name"]


func examine_text() -> String:
	return ContentDB.board(board_id)["examine"]


func _box(size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	box.material = material
	mesh.mesh = box
	mesh.position = at
	add_child(mesh)
