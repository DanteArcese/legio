extends StaticBody3D
## A crafting station: furnace (smelting), anvil (smithing), range or
## campfire (cooking), or tomb (inscribing).

const LOOKS := {
	"furnace": ["Furnace", Color(0.45, 0.25, 0.2), Vector3(1.2, 1.4, 1.2), "Hot enough to smelt ore into bars."],
	"anvil": ["Anvil", Color(0.25, 0.25, 0.28), Vector3(0.9, 0.6, 0.5), "Bring bars and a hammer."],
	"range": ["Cooking range", Color(0.55, 0.45, 0.35), Vector3(1.3, 0.9, 0.8), "A clay oven with a fire beneath."],
	"fire": ["Campfire", Color(0.4, 0.28, 0.18), Vector3(1.0, 0.5, 1.0), "A woodsman's fire, kept burning. Good for cooking fish."],
	"tomb": ["Old tomb", Color(0.42, 0.42, 0.4), Vector3(1.0, 1.1, 2.0), "Curses buried here reach the Manes. Inscribe tablets with a stylus."],
}
## Recipe kinds made at each station.
const KINDS := {"furnace": "smelt", "anvil": "smith", "range": "cook", "fire": "cook", "tomb": "inscribe"}

@export_enum("furnace", "anvil", "range", "tomb", "fire") var kind := "furnace"

var _flame: MeshInstance3D
var _light: OmniLight3D
var _time := 0.0


func recipe_kind() -> String:
	return KINDS[kind]


func display_name() -> String:
	return LOOKS[kind][0]


func examine_text() -> String:
	return LOOKS[kind][3]


## Joins the group before any _ready runs, so the driver can find it.
func _init() -> void:
	collision_layer = 8
	add_to_group("stations")
	add_to_group("navigation_source")


func _ready() -> void:
	var look: Array = LOOKS[kind]
	if kind == "fire":
		_build_fire(look[1])
	else:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = look[2]
		var material := StandardMaterial3D.new()
		material.albedo_color = look[1]
		box.material = material
		mesh.mesh = box
		mesh.position.y = look[2].y / 2.0
		add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = look[2]
	shape.position.y = look[2].y / 2.0
	add_child(shape)
	var label := Label3D.new()
	label.text = look[0]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.outline_size = 8
	label.position.y = look[2].y + 0.4
	add_child(label)


func _process(delta: float) -> void:
	if _flame == null:
		return
	_time += delta
	var flicker := 0.85 + 0.1 * sin(_time * 11.0) + 0.05 * sin(_time * 23.0 + 1.3)
	_flame.scale = Vector3(1.0, flicker, 1.0)
	_light.light_energy = 1.6 * flicker


## Crossed logs in a ring of stones, with a flickering flame and light.
func _build_fire(wood: Color) -> void:
	var wood_material := StandardMaterial3D.new()
	wood_material.albedo_color = wood
	for i in 4:
		var log_mesh := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.08
		cylinder.bottom_radius = 0.09
		cylinder.height = 0.9
		cylinder.material = wood_material
		log_mesh.mesh = cylinder
		log_mesh.rotation = Vector3(deg_to_rad(65), i * PI / 2.0, 0)
		log_mesh.position = Vector3(0, 0.18, 0)
		add_child(log_mesh)
	var stone_material := StandardMaterial3D.new()
	stone_material.albedo_color = Color(0.48, 0.46, 0.43)
	for i in 8:
		var stone := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.16
		sphere.material = stone_material
		stone.mesh = sphere
		var angle := i * TAU / 8.0
		stone.position = Vector3(cos(angle) * 0.55, 0.06, sin(angle) * 0.55)
		add_child(stone)
	_flame = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.22
	cone.height = 0.6
	var fire_material := StandardMaterial3D.new()
	fire_material.albedo_color = Color(1.0, 0.55, 0.15)
	fire_material.emission_enabled = true
	fire_material.emission = Color(1.0, 0.45, 0.1)
	fire_material.emission_energy_multiplier = 2.5
	cone.material = fire_material
	_flame.mesh = cone
	_flame.position.y = 0.4
	add_child(_flame)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.65, 0.35)
	_light.omni_range = 6.0
	_light.position.y = 0.8
	add_child(_light)
