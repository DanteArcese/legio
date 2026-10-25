extends StaticBody3D
## A simple lamp post whose light the day/night cycle switches on at night.

func _init() -> void:
	collision_layer = 8
	add_to_group("navigation_source")


func _ready() -> void:
	var post := MeshInstance3D.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.09
	pole.height = 2.4
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.22, 0.14)
	pole.material = wood
	post.mesh = pole
	post.position.y = 1.2
	add_child(post)
	var flame := MeshInstance3D.new()
	var bowl := SphereMesh.new()
	bowl.radius = 0.14
	bowl.height = 0.22
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1, 0.6, 0.25)
	glow.emission_enabled = true
	glow.emission = Color(1, 0.55, 0.2)
	glow.emission_energy_multiplier = 2.5
	bowl.material = glow
	flame.mesh = bowl
	flame.position.y = 2.5
	add_child(flame)
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
