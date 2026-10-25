extends CharacterBody3D
## Scene body for a monster. The simulation's AI decides where to go
## (combatant.move_target); this node walks there with physics.

const ContentDB := preload("res://scripts/content/content_db.gd")
const Navigation := preload("res://scripts/world/navigation.gd")
const CreatureModel := preload("res://scripts/world/creature_model.gd")

## Collision height and label height per model kind, as multiples of size.
const BODY_HEIGHT := {"quadruped": 0.9, "humanoid": 1.9, "bird": 1.2}
const LABEL_HEIGHT := {"quadruped": 1.3, "humanoid": 2.4, "bird": 1.7}

@export var monster_id := "rat"
@export var move_speed := 2.5
@export var turn_speed := 10.0

@onready var _entity: Node = $SimEntity

var _model: Node3D


func _enter_tree() -> void:
	$SimEntity.monster_id = monster_id


func _ready() -> void:
	var look: Dictionary = ContentDB.monster(monster_id)["appearance"]
	_model = CreatureModel.create(look)
	add_child(_model)
	var size := float(look["size"])
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35 * size
	shape.height = maxf(BODY_HEIGHT[look["model"]] * size, shape.radius * 2.0)
	$Collision.shape = shape
	$Collision.position.y = shape.height / 2.0
	$HpLabel.position.y = LABEL_HEIGHT[look["model"]] * size


func _physics_process(delta: float) -> void:
	var combatant: RefCounted = _entity.combatant
	var direction := Vector3.ZERO
	if combatant and combatant.is_alive() and combatant.move_target != null:
		var offset: Vector3 = (combatant.move_target - global_position) * Vector3(1, 0, 1)
		var stop_distance: float = combatant.reach * 0.8 if combatant.target_id != -1 else 0.2
		if offset.length() > stop_distance:
			var waypoint := Navigation.next_waypoint(get_world_3d(), global_position, combatant.move_target)
			direction = ((waypoint - global_position) * Vector3(1, 0, 1)).normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	_model.animate(delta, Vector2(velocity.x, velocity.z).length())
	if direction != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(turn_speed * delta, 1.0))
