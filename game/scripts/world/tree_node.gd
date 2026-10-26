extends StaticBody3D
## A tree that can be chopped. The simulation tracks felling; this node
## swaps the standing tree for a stump and back. The KitDresser supplies
## the Kenney models; until it does, a greybox trunk and crown stand in.

const ContentDB := preload("res://scripts/content/content_db.gd")
const TRUNK_RADIUS := 0.45
const MODEL_HEIGHT := 1.6

@export var tree_type := "tree"
## How tall the standing tree is, in metres.
@export var height := 5.5

var tree_id := 0
var felled := false
var _standing: Node3D
var _stump: Node3D
var _label: Label3D


## Joins the groups before any _ready runs, so the driver and dresser find it.
func _init() -> void:
	collision_layer = 8
	add_to_group("trees")
	add_to_group("navigation_source")


func _ready() -> void:
	var shape := CollisionShape3D.new()
	shape.shape = CylinderShape3D.new()
	shape.shape.radius = TRUNK_RADIUS
	shape.shape.height = 2.0
	shape.position.y = 1.0
	add_child(shape)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 32
	_label.outline_size = 8
	_label.visibility_range_end = 30.0
	add_child(_label)
	if _standing == null:
		dress(_greybox(), _greybox_stump())
	set_felled(felled)


func display_name() -> String:
	return ContentDB.tree(tree_type).get("name", "Tree")


func examine_text() -> String:
	return ContentDB.tree(tree_type).get("examine", "")


## The Kenney model name for this kind of tree.
func model_name() -> String:
	return ContentDB.tree(tree_type).get("model", "tree_default")


func dress(standing: Node3D, stump: Node3D) -> void:
	for old in [_standing, _stump]:
		if old:
			old.queue_free()
	_standing = standing
	_stump = stump
	_standing.scale *= height / MODEL_HEIGHT
	_standing.rotation.y = float(absi(hash(String(name))) % 360) * PI / 180.0
	add_child(_standing)
	add_child(_stump)
	set_felled(felled)


func set_felled(value: bool) -> void:
	felled = value
	if _standing:
		_standing.visible = not felled
		_stump.visible = felled
	if _label:
		_label.text = "%s stump" % display_name() if felled else display_name()
		_label.position.y = 1.0 if felled else 2.2


func _greybox() -> Node3D:
	var root := Node3D.new()
	var trunk := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.06
	cylinder.bottom_radius = 0.09
	cylinder.height = 0.8
	trunk.mesh = cylinder
	trunk.position.y = 0.4
	trunk.material_override = _material(Color(0.4, 0.28, 0.18))
	root.add_child(trunk)
	var crown := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	crown.mesh = sphere
	crown.position.y = 1.1
	crown.material_override = _material(Color(0.25, 0.45, 0.2))
	root.add_child(crown)
	return root


func _greybox_stump() -> Node3D:
	var stump := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.4
	cylinder.bottom_radius = 0.45
	cylinder.height = 0.4
	stump.mesh = cylinder
	stump.position.y = 0.2
	stump.material_override = _material(Color(0.4, 0.28, 0.18))
	return stump


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
