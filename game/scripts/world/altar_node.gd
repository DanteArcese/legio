extends StaticBody3D
## An altar: pray here to restore favour, and make offerings to train Pietas.
## Heavenly altars burn bright; underworld altars smoulder dark.

@export_enum("heavenly", "underworld") var kind := "heavenly"
@export var title := "Altar"


func _init() -> void:
	collision_layer = 8
	add_to_group("altars")
	add_to_group("navigation_source")


func _ready() -> void:
	var stone := Color(0.85, 0.82, 0.74) if kind == "heavenly" else Color(0.22, 0.2, 0.22)
	var flame := Color(1.0, 0.62, 0.22) if kind == "heavenly" else Color(0.45, 0.85, 0.55)
	_box(Vector3(1.4, 0.9, 0.9), Vector3(0, 0.45, 0), stone)
	_box(Vector3(1.6, 0.12, 1.1), Vector3(0, 0.96, 0), stone.darkened(0.15))
	var bowl := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.3
	var glow := StandardMaterial3D.new()
	glow.albedo_color = flame
	glow.emission_enabled = true
	glow.emission = flame
	glow.emission_energy_multiplier = 2.5
	sphere.material = glow
	bowl.mesh = sphere
	bowl.position = Vector3(0, 1.15, 0)
	add_child(bowl)
	var light := OmniLight3D.new()
	light.light_color = flame
	light.light_energy = 1.2
	light.omni_range = 6.0
	light.position = Vector3(0, 1.4, 0)
	add_child(light)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(1.4, 1.0, 0.9)
	shape.position = Vector3(0, 0.5, 0)
	add_child(shape)
	var label := Label3D.new()
	label.text = title
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.outline_size = 8
	label.position = Vector3(0, 2.0, 0)
	add_child(label)


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
