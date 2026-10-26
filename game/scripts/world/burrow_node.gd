extends StaticBody3D
## A hare burrow or fox den for Hunter traps: a dark hole in a mound of
## earth. Shows a box trap when one is set, with its lid shut once sprung.

const ContentDB := preload("res://scripts/content/content_db.gd")

@export var spot_type := "hare_burrow"

var spot_id := 0
var _trap: Node3D
var _lid: MeshInstance3D


func _init() -> void:
	collision_layer = 8
	add_to_group("hunt_spots")


func _ready() -> void:
	var shape := CollisionShape3D.new()
	shape.shape = CylinderShape3D.new()
	shape.shape.radius = 0.6
	shape.shape.height = 0.5
	shape.position.y = 0.25
	add_child(shape)
	var mound := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.8 if spot_type == "fox_den" else 0.6
	sphere.height = 0.5
	sphere.is_hemisphere = true
	sphere.material = _material(Color(0.42, 0.33, 0.22))
	mound.mesh = sphere
	add_child(mound)
	var hole := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.25
	disc.bottom_radius = 0.25
	disc.height = 0.02
	disc.material = _material(Color(0.08, 0.06, 0.05))
	hole.mesh = disc
	hole.position = Vector3(0.0, 0.24, 0.0)
	add_child(hole)
	_trap = Node3D.new()
	_trap.position = Vector3(0.75, 0, 0)
	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.45, 0.3, 0.6)
	box_mesh.material = _material(Color(0.55, 0.4, 0.25))
	box.mesh = box_mesh
	box.position.y = 0.15
	_trap.add_child(box)
	_lid = MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(0.45, 0.04, 0.3)
	lid_mesh.material = _material(Color(0.45, 0.32, 0.2))
	_lid.mesh = lid_mesh
	_trap.add_child(_lid)
	add_child(_trap)
	var label := Label3D.new()
	label.text = display_name()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.outline_size = 8
	label.position.y = 1.0
	label.visibility_range_end = 30.0
	add_child(label)
	set_trap_state("")


func display_name() -> String:
	return ContentDB.hunt_spot(spot_type)["name"]


func examine_text() -> String:
	return ContentDB.hunt_spot(spot_type)["examine"]


## "" (no trap), "set" (lid propped open), or "caught" (lid shut).
func set_trap_state(state: String) -> void:
	_trap.visible = not state.is_empty()
	if state == "caught":
		_lid.position = Vector3(0, 0.32, 0)
		_lid.rotation = Vector3.ZERO
	else:
		_lid.position = Vector3(0, 0.42, -0.2)
		_lid.rotation = Vector3(-0.9, 0, 0)


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
