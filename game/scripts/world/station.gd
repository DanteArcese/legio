extends StaticBody3D
## A crafting station: furnace (smelting), anvil (smithing), or range (cooking).

const LOOKS := {
	"furnace": ["Furnace", Color(0.45, 0.25, 0.2), Vector3(1.2, 1.4, 1.2)],
	"anvil": ["Anvil", Color(0.25, 0.25, 0.28), Vector3(0.9, 0.6, 0.5)],
	"range": ["Cooking range", Color(0.55, 0.45, 0.35), Vector3(1.3, 0.9, 0.8)],
}
## Recipe kinds made at each station.
const KINDS := {"furnace": "smelt", "anvil": "smith", "range": "cook"}

@export_enum("furnace", "anvil", "range") var kind := "furnace"


func recipe_kind() -> String:
	return KINDS[kind]


## Joins the group before any _ready runs, so the driver can find it.
func _init() -> void:
	add_to_group("stations")


func _ready() -> void:
	var look: Array = LOOKS[kind]
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
