extends Node3D
## Items dropped on the ground. Picking up arrives with the inventory (#14).

const ContentDB := preload("res://scripts/content/content_db.gd")
const LIFETIME := 120.0

var items: Array = []


static func spawn(parent: Node, at: Vector3, p_items: Array) -> Node3D:
	var pile := new()
	pile.items = p_items
	parent.add_child(pile)
	pile.global_position = Vector3(at.x, 0.0, at.z)
	return pile


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.2, 0.4)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.7, 0.3)
	box.material = material
	mesh.mesh = box
	mesh.position.y = 0.1
	add_child(mesh)

	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.outline_size = 8
	label.position.y = 0.6
	var lines := PackedStringArray()
	for drop in items:
		var name: String = ContentDB.item(drop["item"])["name"]
		lines.append(name if drop["quantity"] == 1 else "%s x%d" % [name, drop["quantity"]])
	label.text = "\n".join(lines)
	add_child(label)
	get_tree().create_timer(LIFETIME, false).timeout.connect(queue_free)
