extends Node
## Gives an NPC body (this node's parent) an idle KayKit character in place
## of its placeholder capsule.

const KaykitCharacter := preload("res://scripts/world/kaykit_character.gd")

@export var scene := "adventurers/Barbarian"
@export var weapon := ""
@export var hide_meshes: Array[String] = []

var model: Node3D


func _ready() -> void:
	var body := get_parent() as Node3D
	var placeholder := body.get_node_or_null("Mesh")
	if placeholder:
		placeholder.visible = false
	model = KaykitCharacter.create({"scene": scene, "weapon": weapon, "hide": hide_meshes})
	model.position.y = -1.0
	body.add_child.call_deferred(model)


func _physics_process(delta: float) -> void:
	if model:
		model.animate(delta, 0.0)
