extends CharacterBody3D
## Scene body for a monster. The simulation's AI decides where to go
## (combatant.move_target); this node walks there with physics.

const ContentDB := preload("res://scripts/content/content_db.gd")

@export var monster_id := "rat"
@export var move_speed := 2.5
@export var turn_speed := 10.0

@onready var _entity: Node = $SimEntity


func _enter_tree() -> void:
	$SimEntity.monster_id = monster_id


func _ready() -> void:
	var look: Dictionary = ContentDB.monster(monster_id)["appearance"]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.html(look["color"])
	$Mesh.material_override = material
	var size := float(look["size"])
	$Mesh.scale = Vector3.ONE * size
	$Collision.scale = Vector3.ONE * size
	$Mesh.position.y = size
	$Collision.position.y = size
	$HpLabel.position.y = size * 2.0 + 0.4


func _physics_process(delta: float) -> void:
	var combatant: RefCounted = _entity.combatant
	var direction := Vector3.ZERO
	if combatant and combatant.is_alive() and combatant.move_target != null:
		var offset: Vector3 = (combatant.move_target - global_position) * Vector3(1, 0, 1)
		var stop_distance: float = combatant.reach * 0.8 if combatant.target_id != -1 else 0.2
		if offset.length() > stop_distance:
			direction = offset.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	if direction != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(turn_speed * delta, 1.0))
