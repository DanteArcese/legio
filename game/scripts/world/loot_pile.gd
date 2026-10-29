extends Node3D
## Shows a ground item pile from the simulation. The simulation owns the
## items and their expiry; this node only mirrors them.
##
## To keep the ground readable, the label only shows when the player is
## close, lists at most a few entries, and turns gold for valuable drops.

const ContentDB := preload("res://scripts/content/content_db.gd")

const LABEL_RANGE := 6.0
const MAX_LINES := 3
## A pile worth this much in total (or any item worth VALUABLE_ITEM) is highlighted.
const VALUABLE_TOTAL := 100
const VALUABLE_ITEM := 50
const NORMAL_COLOR := Color(1, 1, 1)
const VALUABLE_COLOR := Color(1.0, 0.82, 0.3)

var pile_id := 0
var items: Array = []

var _label: Label3D
var _material := StandardMaterial3D.new()


static func spawn(parent: Node, id: int, at: Vector3, p_items: Array) -> Node3D:
	var pile := new()
	pile.pile_id = id
	pile.items = p_items
	pile.add_to_group("loot_piles")
	parent.add_child(pile)
	pile.global_position = Vector3(at.x, _ground_y(pile, at), at.z)
	return pile


## The ground under a drop: a ray down onto the terrain (layer 1) from just
## above where the body stood, so piles sit on hills instead of sinking
## into them (and never land on a dungeon's roof). Flat ground is y 0.
static func _ground_y(node: Node3D, at: Vector3) -> float:
	var space := node.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, at.y + 2.0, at.z), Vector3(at.x, at.y - 8.0, at.z), 1)
	var hit := space.intersect_ray(query)
	return hit["position"].y if not hit.is_empty() else 0.0


func set_items(p_items: Array) -> void:
	items = p_items
	_refresh_label()


func is_valuable() -> bool:
	var total := 0
	for drop in items:
		var value: int = ContentDB.item(drop["item"])["value"]
		if value >= VALUABLE_ITEM:
			return true
		total += value * drop["quantity"]
	return total >= VALUABLE_TOTAL


func is_label_shown() -> bool:
	return _label != null and _label.visible


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.2, 0.4)
	box.material = _material
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


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := player != null and Vector2(player.global_position.x - global_position.x,
		player.global_position.z - global_position.z).length() <= LABEL_RANGE
	_label.visible = near


func _refresh_label() -> void:
	if _label == null:
		return
	var lines := PackedStringArray()
	for drop in items.slice(0, MAX_LINES):
		var name: String = ContentDB.item(drop["item"])["name"]
		lines.append(name if drop["quantity"] == 1 else "%s x%d" % [name, drop["quantity"]])
	if items.size() > MAX_LINES:
		lines.append("+%d more" % (items.size() - MAX_LINES))
	_label.text = "\n".join(lines)
	var valuable := is_valuable()
	_label.modulate = VALUABLE_COLOR if valuable else NORMAL_COLOR
	_material.albedo_color = Color(1.0, 0.78, 0.2) if valuable else Color(0.85, 0.7, 0.3)
	_material.emission_enabled = valuable
	_material.emission = Color(0.8, 0.55, 0.1)
