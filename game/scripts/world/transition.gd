extends StaticBody3D
## A doorway between areas (the barrow entrance, its exit). Using it moves
## the player to destination, facing into the new area.

@export var verb := "Enter"
@export var title := "Barrow entrance"
@export_multiline var examine_text := ""
@export var destination := Vector3.ZERO
@export var size := Vector3(1.6, 2.2, 0.5)
@export var color := Color(0.12, 0.1, 0.09)
## Only villa owners may go this way (the road to the villa grounds).
@export var requires_villa := false
## Said the first time the doorway is used; using it again goes through.
@export_multiline var warning := ""

var warned := false


func _init() -> void:
	collision_layer = 8
	add_to_group("transitions")
	add_to_group("navigation_source")


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	box.material = material
	mesh.mesh = box
	mesh.position.y = size.y / 2.0
	add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	shape.position.y = size.y / 2.0
	add_child(shape)
	var label := Label3D.new()
	label.text = "%s\n(%s)" % [title, verb]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.outline_size = 8
	label.position.y = 2.6
	add_child(label)
