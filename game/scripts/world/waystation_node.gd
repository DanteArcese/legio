extends StaticBody3D
## A waystation of the cursus publicus: a little open-sided roofed stable, a
## milestone, and a sign. The simulation unlocks it when you walk up, and its menu rides
## the post to the others.

const Waystations := preload("res://scripts/sim/waystations.gd")

@export var station_id := "castra"


func _init() -> void:
	collision_layer = 8
	# Joined here, before the sim driver's _ready looks the stations up. The
	# stable is open-sided (you walk in under the roof to the stationmaster),
	# so it isn't a navigation obstacle; only the milestone is solid.
	add_to_group("waystations")


func _ready() -> void:
	var timber := _material(Color(0.45, 0.33, 0.22))
	var tile := _material(Color(0.62, 0.3, 0.2))
	var stone := _material(Color(0.78, 0.74, 0.66))
	for x in [-1.4, 1.4]:
		for z in [-0.9, 0.9]:
			_box(Vector3(0.2, 2.2, 0.2), Vector3(x, 1.1, z), timber)
	_box(Vector3(3.4, 0.25, 2.4), Vector3(0, 2.3, 0), tile)
	_box(Vector3(2.6, 1.0, 0.1), Vector3(0, 0.5, -0.9), timber)
	var milestone := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.22
	shaft.bottom_radius = 0.26
	shaft.height = 1.3
	shaft.material = stone
	milestone.mesh = shaft
	milestone.position = Vector3(2.2, 0.65, 0.8)
	add_child(milestone)
	var shape := CollisionShape3D.new()
	shape.shape = CylinderShape3D.new()
	shape.shape.radius = 0.3
	shape.shape.height = 1.3
	shape.position = milestone.position
	add_child(shape)
	var label := Label3D.new()
	label.text = "Waystation\n(%s)" % Waystations.station(station_id).get("name", station_id)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.outline_size = 8
	label.position.y = 3.0
	label.visibility_range_end = 30.0
	add_child(label)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


func _box(size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	mesh.position = at
	add_child(mesh)
