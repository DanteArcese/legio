extends StaticBody3D
## A farming patch: a bed of dark soil in rows. The crop shows as rows of
## plants that grow with each stage, flowering in the crop's colour once
## it's ready to harvest.

const ContentDB := preload("res://scripts/content/content_db.gd")
const SOIL := Color(0.3, 0.22, 0.15)
const ROWS := 3
const PER_ROW := 4

@export var patch_type := "herb_patch"

var patch_id := 0
var crop := ""
var stage := 0
var grown := false
var _plants: Node3D
var _label: Label3D


func _init() -> void:
	collision_layer = 8
	add_to_group("patches")
	# Solid to walkers, so the navmesh must route around it.
	add_to_group("navigation_source")


func _ready() -> void:
	var size := _size()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(size.x, 0.3, size.y)
	shape.position.y = 0.15
	add_child(shape)
	var bed := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, 0.12, size.y)
	var soil := StandardMaterial3D.new()
	soil.albedo_color = SOIL
	box.material = soil
	bed.mesh = box
	bed.position.y = 0.06
	add_child(bed)
	_plants = Node3D.new()
	add_child(_plants)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 28
	_label.outline_size = 8
	_label.position.y = 1.2
	_label.visibility_range_end = 30.0
	add_child(_label)
	show_crop("", 0, false)


func display_name() -> String:
	return ContentDB.patch(patch_type)["name"]


func examine_text() -> String:
	return ContentDB.patch(patch_type)["examine"]


func show_crop(crop_id: String, crop_stage: int, is_ready: bool) -> void:
	crop = crop_id
	stage = crop_stage
	grown = is_ready
	for child in _plants.get_children():
		child.queue_free()
	if crop.is_empty():
		_label.text = display_name()
		return
	var data := ContentDB.crop(crop)
	_label.text = "%s (%s)" % [display_name(), data["name"].to_lower() + (", ready" if grown else "")]
	var growth := clampf(float(stage + 1) / float(data["stages"] + 1), 0.15, 1.0)
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.32, 0.55, 0.25).lerp(Color.html(data["color"]), 0.35)
	var flower := StandardMaterial3D.new()
	flower.albedo_color = Color.html(data["color"])
	var size := _size()
	for row in ROWS:
		for i in PER_ROW:
			var plant := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.02
			cone.bottom_radius = 0.16 * growth + 0.04
			cone.height = 0.7 * growth
			cone.material = leaf
			plant.mesh = cone
			plant.position = Vector3(-size.x / 2.0 + size.x * (i + 0.5) / PER_ROW, 0.12 + cone.height / 2.0,
				-size.y / 2.0 + size.y * (row + 0.5) / ROWS)
			_plants.add_child(plant)
			if grown:
				var bloom := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radius = 0.09
				sphere.height = 0.18
				sphere.material = flower
				bloom.mesh = sphere
				bloom.position = plant.position + Vector3(0, cone.height / 2.0 + 0.05, 0)
				_plants.add_child(bloom)


func _size() -> Vector2:
	return Vector2(2.4, 1.8) if patch_type == "herb_patch" else Vector2(4.0, 1.8)
