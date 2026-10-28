extends StaticBody3D
## A strongbox to crack with a lockpick (Thieving): Kenney's iron-bound
## chest, its lid thrown open while it's empty.

const ContentDB := preload("res://scripts/content/content_db.gd")

@export var box_type := "warehouse_strongbox"

var strongbox_id := 0
var empty := false
var _label: Label3D
var _lid: MeshInstance3D


func _init() -> void:
	collision_layer = 8
	add_to_group("strongboxes")
	add_to_group("navigation_source")


func _ready() -> void:
	var model: Node3D = load("res://assets/kenney/survival/chest.glb").instantiate()
	model.scale = Vector3.ONE * 3.0
	add_child(model)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(0.9, 0.7, 1.2)
	shape.position.y = 0.35
	add_child(shape)
	# A dark open mouth on top, shown while the box is empty.
	_lid = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.02, 1.0)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.06, 0.05)
	box.material = dark
	_lid.mesh = box
	_lid.position.y = 0.72
	add_child(_lid)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 28
	_label.outline_size = 8
	_label.position.y = 1.4
	_label.visibility_range_end = 25.0
	add_child(_label)
	set_empty(false)


func display_name() -> String:
	return data()["name"]


func examine_text() -> String:
	return data()["examine"]


func data() -> Dictionary:
	return ContentDB.data()["thieving"]["strongboxes"][box_type]


func set_empty(value: bool) -> void:
	empty = value
	_lid.visible = empty
	_label.text = display_name() + (" (emptied)" if empty else "")
