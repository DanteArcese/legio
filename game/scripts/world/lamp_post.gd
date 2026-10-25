extends StaticBody3D
## A lantern post whose light the day/night cycle switches on at night.

func _init() -> void:
	collision_layer = 8
	add_to_group("navigation_source")


func _ready() -> void:
	# Kenney Fantasy Town lantern (CC0), scaled to a 2.5 m post.
	var lantern: Node3D = preload("res://assets/kenney/town/lantern.glb").instantiate()
	lantern.scale = Vector3.ONE * 1.6
	add_child(lantern)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.15
	cylinder.height = 2.4
	shape.shape = cylinder
	shape.position.y = 1.2
	add_child(shape)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.68, 0.38)
	light.omni_range = 9.0
	light.position.y = 2.5
	light.shadow_enabled = false
	light.add_to_group("lamps")
	add_child(light)
