extends StaticBody3D
## A market stall in the forum that can be stolen from. The KitDresser
## supplies its Kenney stall model; the goods on the counter vanish while
## the stall is empty and come back when it restocks.

const ContentDB := preload("res://scripts/content/content_db.gd")
const GOODS_COLORS := {"bread": Color(0.82, 0.62, 0.35), "linen": Color(0.92, 0.9, 0.82), "silver_fibula": Color(0.8, 0.82, 0.86)}

@export var stall_type := "bakers_stall"

var stall_id := 0
var empty := false
var _label: Label3D
var _goods: Node3D


func _init() -> void:
	collision_layer = 8
	add_to_group("stalls")
	add_to_group("navigation_source")


func _ready() -> void:
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(2.6, 1.2, 1.4)
	shape.position.y = 0.6
	add_child(shape)
	_goods = Node3D.new()
	var color: Color = GOODS_COLORS.get(ContentDB.stall(stall_type)["loot"]["item"], Color.WHITE)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.6 if stall_type == "silversmiths_stall" else 0.0
	for i in 4:
		var piece := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.32, 0.14, 0.24)
		box.material = material
		piece.mesh = box
		piece.position = Vector3(-0.6 + i * 0.4, 1.12, 0.1)
		_goods.add_child(piece)
	add_child(_goods)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 32
	_label.outline_size = 8
	_label.position.y = 2.9
	_label.visibility_range_end = 30.0
	add_child(_label)
	set_empty(false)


func display_name() -> String:
	return ContentDB.stall(stall_type)["name"]


func examine_text() -> String:
	return ContentDB.stall(stall_type)["examine"]


func model_name() -> String:
	return ContentDB.stall(stall_type)["model"]


func dress(model: Node3D) -> void:
	add_child(model)


func set_empty(value: bool) -> void:
	empty = value
	_goods.visible = not empty
	_label.text = display_name() + ("  (empty)" if empty else "")
