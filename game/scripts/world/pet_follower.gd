extends StaticBody3D
## A pet trotting after the player: keeps a little behind them, catches up
## when left behind, and appears at their side after a teleport. Clickable
## (layer 32) for its menu, but nothing collides with it.

const CreatureModel := preload("res://scripts/world/creature_model.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const LAYER := 32
## How far behind the player it settles, and how far it can lag before it
## simply reappears beside them.
const HEEL := 1.3
const TELEPORT := 14.0
const SPEED := 6.5

var pet_id := ""
var _player: Node3D
var _model: Node3D


static func spawn(parent: Node, player: Node3D, p_pet_id: String) -> Node3D:
	var pet := new()
	pet.pet_id = p_pet_id
	pet._player = player
	pet.name = "Pet"
	parent.add_child(pet)
	pet.global_position = player.global_position - player.global_basis.z * -HEEL + Vector3(0, -1.0, 0)
	return pet


func _init() -> void:
	collision_layer = LAYER
	collision_mask = 0
	add_to_group("pets")


func _ready() -> void:
	_model = CreatureModel.create(ContentDB.item(pet_id)["pet"])
	add_child(_model)
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.shape.radius = 0.4
	shape.position.y = 0.3
	add_child(shape)


func title() -> String:
	return ContentDB.item(pet_id)["name"]


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var feet := _player.global_position + Vector3(0, -1.0, 0)
	var offset := feet - global_position
	offset.y = 0.0
	var distance := offset.length()
	var speed := 0.0
	if distance > TELEPORT:
		global_position = feet + Vector3(HEEL, 0, 0)
	elif distance > HEEL:
		var step := minf(SPEED * delta * clampf(distance / 2.0, 0.6, 1.6), distance - HEEL)
		global_position += offset.normalized() * step
		speed = step / delta
		look_at(Vector3(feet.x, global_position.y, feet.z), Vector3.UP, true)
	global_position.y = feet.y
	if _model.has_method("animate"):
		_model.animate(delta, speed)
