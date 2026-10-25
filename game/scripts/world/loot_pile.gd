extends Node3D
## Shows a ground item pile from the simulation. The simulation owns the
## items and their expiry; this node only mirrors them.

const ContentDB := preload("res://scripts/content/content_db.gd")
var pile_id := 0
var items: Array = []

var _label: Label3D


static func spawn(parent: Node, id: int, at: Vector3, p_items: Array) -> Node3D:
	var pile := new()
	pile.pile_id = id
	pile.items = p_items
	pile.add_to_group("loot_piles")
	parent.add_child(pile)
	pile.global_position = Vector3(at.x, 0.0, at.z)
	return pile


func set_items(p_items: Array) -> void:
	items = p_items
	_refresh_label()


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

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 32
	_label.outline_size = 8
	_label.position.y = 0.6
	add_child(_label)
	_refresh_label()


func _refresh_label() -> void:
	if _label == null:
		return
	var lines := PackedStringArray()
	for drop in items:
		var name: String = ContentDB.item(drop["item"])["name"]
		lines.append(name if drop["quantity"] == 1 else "%s x%d" % [name, drop["quantity"]])
	_label.text = "\n".join(lines)
