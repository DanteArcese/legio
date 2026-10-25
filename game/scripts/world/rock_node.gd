extends StaticBody3D
## A mineable rock. The simulation tracks depletion; this node shows it.

const ContentDB := preload("res://scripts/content/content_db.gd")
const DEPLETED_COLOR := Color(0.35, 0.33, 0.32)

@export var rock_type := "copper_rock"

var rock_id := 0
var _material := StandardMaterial3D.new()


## Joins the group before any _ready runs, so the driver can find it.
func _init() -> void:
	add_to_group("rocks")


func _ready() -> void:
	var data := ContentDB.rock(rock_type)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 0.9
	sphere.material = _material
	mesh.mesh = sphere
	mesh.position.y = 0.35
	add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.shape.radius = 0.55
	shape.position.y = 0.35
	add_child(shape)
	var label := Label3D.new()
	label.text = data["name"]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.outline_size = 8
	label.position.y = 1.2
	add_child(label)
	set_depleted(false)


func set_depleted(depleted: bool) -> void:
	_material.albedo_color = DEPLETED_COLOR if depleted else Color.html(ContentDB.rock(rock_type)["color"])
