extends StaticBody3D
## A crafting station: furnace (smelting), anvil (smithing), range or
## campfire (cooking), tomb (inscribing), and the rest: tanning rack, sawpit,
## garum vat, potter's wheel, kiln, and the villa's olive and wine presses.

const LOOKS := {
	"furnace": ["Furnace", Color(0.45, 0.25, 0.2), Vector3(1.2, 1.4, 1.2), "Hot enough to smelt ore into bars."],
	"anvil": ["Anvil", Color(0.25, 0.25, 0.28), Vector3(0.9, 0.6, 0.5), "Bring bars and a hammer."],
	"range": ["Cooking range", Color(0.55, 0.45, 0.35), Vector3(1.3, 0.9, 0.8), "A clay oven with a fire beneath."],
	"fire": ["Campfire", Color(0.4, 0.28, 0.18), Vector3(1.0, 0.5, 1.0), "A woodsman's fire, kept burning. Good for cooking fish."],
	"tanning_rack": ["Tanning rack", Color(0.5, 0.36, 0.22), Vector3(1.4, 1.6, 0.4), "Hides stretched to cure. Tan boar hides into leather here."],
	"sawpit": ["Sawpit", Color(0.45, 0.33, 0.22), Vector3(2.0, 1.0, 0.8), "A log on trestles and a two-man saw. Saw logs into planks here."],
	"garum_vat": ["Garum vat", Color(0.55, 0.5, 0.45), Vector3(1.4, 0.8, 1.4), "A stone vat of fish and salt, fermenting in the sun. The smell is something else."],
	"tomb": ["Old tomb", Color(0.42, 0.42, 0.4), Vector3(1.0, 1.1, 2.0), "Curses buried here reach the Manes. Inscribe tablets with a stylus."],
	"potters_wheel": ["Potter's wheel", Color(0.5, 0.38, 0.26), Vector3(1.0, 0.9, 1.0), "A kick-wheel and a bench. Throw clay into pots here."],
	"kiln": ["Kiln", Color(0.62, 0.38, 0.26), Vector3(1.4, 1.6, 1.4), "A beehive kiln of brick. Fire pots, and melt sand into glass with a blowpipe."],
	"olive_press": ["Olive press", Color(0.48, 0.36, 0.24), Vector3(1.6, 1.8, 1.6), "A stone basin under a screw and beam. Four olives make an amphora of oil."],
	"wine_press": ["Wine press", Color(0.45, 0.3, 0.24), Vector3(1.6, 1.8, 1.6), "A treading floor and a beam press. Five bunches of grapes fill an amphora."],
}
## Recipe kinds made at each station.
const KINDS := {"furnace": "smelt", "anvil": "smith", "range": "cook", "fire": "cook", "tomb": "inscribe", "tanning_rack": "tan", "garum_vat": "garum", "sawpit": "saw",
	"potters_wheel": "throw", "kiln": "kiln", "olive_press": "press_oil", "wine_press": "press_wine"}

@export_enum("furnace", "anvil", "range", "tomb", "fire", "tanning_rack", "garum_vat", "sawpit", "potters_wheel", "kiln", "olive_press", "wine_press") var kind := "furnace"

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
	match kind:
		"fire":
			_build_fire()
		"anvil":
			_add_model("workbench-anvil", 3.0)
		"furnace":
			_build_furnace()
		"range":
			_build_range()
		"tomb":
			_build_tomb()
		"tanning_rack":
			_build_tanning_rack()
		"garum_vat":
			_build_garum_vat()
		"sawpit":
			_build_sawpit()
		"potters_wheel":
			_build_potters_wheel()
		"kiln":
			_build_kiln()
		"olive_press", "wine_press":
			_build_press()
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
	if _light == null:
		return
	_time += delta
	var flicker := 0.85 + 0.1 * sin(_time * 11.0) + 0.05 * sin(_time * 23.0 + 1.3)
	if _flame:
		_flame.scale = Vector3(1.0, flicker, 1.0)
	_light.light_energy = 1.6 * flicker


## Kenney's campfire pit, with a flickering flame and light.
func _build_fire() -> void:
	_add_model("campfire-pit", 3.6)
	_add_glow(Vector3(0, 0.4, 0), 0.6)


## A Kenney Survival Kit model (CC0), scaled up from its tiny units.
func _add_model(model: String, size: float) -> void:
	var instance: Node3D = load("res://assets/kenney/survival/%s.glb" % model).instantiate()
	instance.scale = Vector3.ONE * size
	add_child(instance)


## A kick-wheel: a heavy flywheel below, the throwing head above, a bench.
func _build_potters_wheel() -> void:
	var wood := Color(0.5, 0.38, 0.26)
	_add_cylinder(0.45, 0.12, Vector3(0, 0.12, 0), wood.darkened(0.2))
	_add_cylinder(0.06, 0.7, Vector3(0, 0.45, 0), wood.darkened(0.35))
	_add_cylinder(0.28, 0.08, Vector3(0, 0.8, 0), Color(0.6, 0.42, 0.3))
	_add_cylinder(0.12, 0.18, Vector3(0, 0.93, 0), Color(0.66, 0.46, 0.34))
	_add_box(Vector3(0.9, 0.08, 0.35), Vector3(0, 0.55, 0.6), wood)


## A beehive kiln of red brick with a glowing firebox.
func _build_kiln() -> void:
	var brick := Color(0.62, 0.38, 0.26)
	_add_cylinder(0.7, 0.9, Vector3(0, 0.45, 0), brick)
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.7
	sphere.height = 1.2
	sphere.is_hemisphere = true
	sphere.material = _material(brick.darkened(0.08))
	dome.mesh = sphere
	dome.position.y = 0.9
	add_child(dome)
	_add_box(Vector3(0.45, 0.35, 0.05), Vector3(0, 0.3, 0.71), Color(1.0, 0.45, 0.1), true)
	_add_glow(Vector3(0, 0.4, 0.95), 0.0)


## A stone bloomery: a squat stack with a chimney and a glowing mouth.
func _build_furnace() -> void:
	var stone := Color(0.5, 0.42, 0.36)
	_add_box(Vector3(1.3, 0.9, 1.3), Vector3(0, 0.45, 0), stone)
	_add_box(Vector3(1.0, 0.5, 1.0), Vector3(0, 1.15, 0), stone.darkened(0.1))
	_add_cylinder(0.22, 0.8, Vector3(0, 1.75, 0), stone.darkened(0.2))
	_add_box(Vector3(0.5, 0.4, 0.05), Vector3(0, 0.35, 0.66), Color(1.0, 0.45, 0.1), true)
	_add_glow(Vector3(0, 0.5, 0.9), 0.0)


## A domed clay oven on a stone base, its mouth aglow.
func _build_range() -> void:
	_add_box(Vector3(1.4, 0.5, 1.0), Vector3(0, 0.25, 0), Color(0.55, 0.5, 0.45))
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 0.8
	sphere.is_hemisphere = true
	sphere.material = _material(Color(0.68, 0.42, 0.28))
	dome.mesh = sphere
	dome.position.y = 0.5
	add_child(dome)
	_add_box(Vector3(0.36, 0.24, 0.05), Vector3(0, 0.66, 0.5), Color(1.0, 0.5, 0.15), true)
	_add_glow(Vector3(0, 0.7, 0.8), 0.0)


## A weathered stone sarcophagus with a lid and a small stele.
func _build_tomb() -> void:
	var stone := Color(0.5, 0.5, 0.48)
	_add_box(Vector3(1.0, 0.8, 2.0), Vector3(0, 0.4, 0), stone)
	_add_box(Vector3(1.1, 0.18, 2.1), Vector3(0, 0.89, 0), stone.lightened(0.08))
	_add_box(Vector3(0.7, 1.2, 0.18), Vector3(0, 0.6, -1.15), stone.darkened(0.12))


## A log on two trestles, half sawn through, with the saw left in the cut.
func _build_sawpit() -> void:
	var wood := Color(0.45, 0.33, 0.22)
	for x in [-0.7, 0.7]:
		_add_box(Vector3(0.12, 0.7, 0.7), Vector3(x, 0.35, 0), wood.darkened(0.25))
	_add_cylinder(0.22, 2.0, Vector3(0, 0.88, 0), wood)
	get_child(get_child_count() - 1).rotation.z = PI / 2.0
	_add_box(Vector3(0.04, 0.5, 0.9), Vector3(0.2, 1.1, 0), Color(0.6, 0.6, 0.62))


## A low stone tank, brimming with dark brine, beside a stack of amphorae.
func _build_garum_vat() -> void:
	var stone := Color(0.6, 0.56, 0.5)
	_add_box(Vector3(1.4, 0.7, 1.4), Vector3(0, 0.35, 0), stone)
	_add_box(Vector3(1.15, 0.05, 1.15), Vector3(0, 0.68, 0), Color(0.32, 0.26, 0.16))
	for i in 3:
		var jar := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.16
		capsule.height = 0.6
		capsule.material = _material(Color(0.7, 0.42, 0.26))
		jar.mesh = capsule
		jar.position = Vector3(1.0, 0.3, -0.45 + i * 0.4)
		add_child(jar)


## A round stone basin (stained purple for wine) under a screw press: two
## uprights, a crossbeam, and the screw.
func _build_press() -> void:
	var wood := Color(0.45, 0.32, 0.2)
	var basin := Color(0.6, 0.56, 0.5) if kind == "olive_press" else Color(0.5, 0.38, 0.42)
	_add_cylinder(0.75, 0.5, Vector3(0, 0.25, 0), basin)
	_add_cylinder(0.55, 0.12, Vector3(0, 0.56, 0), wood)
	for x in [-0.7, 0.7]:
		_add_box(Vector3(0.14, 1.8, 0.14), Vector3(x, 0.9, 0), wood)
	_add_box(Vector3(1.6, 0.16, 0.18), Vector3(0, 1.7, 0), wood)
	_add_cylinder(0.07, 1.0, Vector3(0, 1.15, 0), Color(0.36, 0.26, 0.16))


## Two posts and a crossbar with a hide stretched between them.
func _build_tanning_rack() -> void:
	var wood := Color(0.45, 0.32, 0.2)
	for x in [-0.65, 0.65]:
		_add_cylinder(0.06, 1.7, Vector3(x, 0.85, 0), wood)
	_add_box(Vector3(1.5, 0.1, 0.1), Vector3(0, 1.6, 0), wood)
	_add_box(Vector3(1.1, 1.1, 0.03), Vector3(0, 0.95, 0), Color(0.62, 0.46, 0.32))


func _add_box(size: Vector3, at: Vector3, color: Color, glowing := false) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = _material(color, glowing)
	mesh.mesh = box
	mesh.position = at
	add_child(mesh)


func _add_cylinder(radius: float, height: float, at: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.material = _material(color)
	mesh.mesh = cylinder
	mesh.position = at
	add_child(mesh)


static func _material(color: Color, glowing := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glowing:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
	return material


## A flickering orange light, and a flame cone when flame_height > 0.
func _add_glow(at: Vector3, flame_height: float) -> void:
	if flame_height > 0.0:
		_flame = MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.22
		cone.height = flame_height
		var fire_material := StandardMaterial3D.new()
		fire_material.albedo_color = Color(1.0, 0.55, 0.15)
		fire_material.emission_enabled = true
		fire_material.emission = Color(1.0, 0.45, 0.1)
		fire_material.emission_energy_multiplier = 2.5
		cone.material = fire_material
		_flame.mesh = cone
		_flame.position = at
		add_child(_flame)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.65, 0.35)
	_light.omni_range = 5.0
	_light.position = at + Vector3(0, 0.4, 0)
	add_child(_light)
