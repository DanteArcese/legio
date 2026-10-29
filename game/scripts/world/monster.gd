extends CharacterBody3D
## Scene body for a monster. The simulation's AI decides where to go
## (combatant.move_target); this node walks there with physics.

const ContentDB := preload("res://scripts/content/content_db.gd")
const Navigation := preload("res://scripts/world/navigation.gd")
const CreatureModel := preload("res://scripts/world/creature_model.gd")
const KaykitCharacter := preload("res://scripts/world/kaykit_character.gd")
const CritterModel := preload("res://scripts/world/critter_model.gd")

## Collision height and label height per model kind, as multiples of size.
const BODY_HEIGHT := {"quadruped": 0.9, "humanoid": 1.9, "bird": 1.2, "kaykit": 1.9}
const LABEL_HEIGHT := {"quadruped": 1.3, "humanoid": 2.4, "bird": 1.7, "kaykit": 2.4}

@export var monster_id := "rat"
@export var move_speed := 2.5
@export var turn_speed := 10.0

@onready var _entity: Node = $SimEntity

var _model: Node3D
var _radius := 0.35
## Near enough to the player to be seen: only these animate and keep apart.
var _near_player := true


## Monsters ease apart from each other and the player rather than collide
## (so crowds never trap the player): this fast, scaled by how deep the overlap is.
const SEPARATION_SPEED := 3.0
## Only monsters this close to the player keep apart; farther ones can't be
## seen overlapping.
const SEPARATION_RANGE := 20.0
static var _bodies: Array = []
static var _bodies_frame := -1
const PLAYER_RADIUS := 0.35

## Frames a cached waypoint lasts before the path is queried again.
const PATH_REFRESH_FRAMES := 15
## Monsters farther than this from the player stop animating (checked now and then).
const ANIMATE_RANGE := 70.0
const ANIMATE_CHECK_FRAMES := 30
var _animate_check := 0
var _waypoint := Vector3.INF
var _path_target := Vector3.INF
var _path_frames := 0

func _enter_tree() -> void:
	$SimEntity.monster_id = monster_id


func _ready() -> void:
	var look: Dictionary = ContentDB.monster(monster_id)["appearance"]
	match look["model"]:
		"kaykit":
			_model = KaykitCharacter.create(look)
		"quadruped", "bird":
			_model = CritterModel.create(look)
		_:
			_model = CreatureModel.create(look)
	add_child(_model)
	_entity.combat_moment.connect(_on_combat_moment)
	var size := float(look["size"])
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35 * size
	_radius = shape.radius
	add_to_group("monster_bodies")
	shape.height = maxf(BODY_HEIGHT[look["model"]] * size, shape.radius * 2.0)
	$Collision.shape = shape
	$Collision.position.y = shape.height / 2.0
	$HpLabel.position.y = LABEL_HEIGHT[look["model"]] * size


func has_animated_model() -> bool:
	return _model is KaykitCharacter or _model is CritterModel


func _on_combat_moment(moment: String, info: Dictionary) -> void:
	if not has_animated_model():
		return
	match moment:
		"attack":
			_model.attack()
		"hurt":
			_model.hurt()
		"die":
			_model.die()
		"revive":
			_model.revive()


func _physics_process(delta: float) -> void:
	var combatant: RefCounted = _entity.combatant
	var direction := Vector3.ZERO
	if combatant and combatant.is_alive() and combatant.move_target != null:
		var offset: Vector3 = (combatant.move_target - global_position) * Vector3(1, 0, 1)
		var stop_distance: float = combatant.reach * 0.8 if combatant.target_id != -1 else 0.2
		if offset.length() > stop_distance:
			var waypoint := _waypoint_toward(combatant.move_target)
			var step: Vector3 = (waypoint - global_position) * Vector3(1, 0, 1)
			direction = step.normalized() if step.length() > 0.01 else Vector3.ZERO
	var push := _separation() if _near_player and combatant and combatant.is_alive() else Vector3.ZERO
	velocity.x = direction.x * move_speed + push.x * SEPARATION_SPEED
	velocity.z = direction.z * move_speed + push.z * SEPARATION_SPEED
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	_entity.rescue_if_fallen()
	_animate_check -= 1
	if _animate_check <= 0 and _model.has_method("set_animating"):
		_animate_check = ANIMATE_CHECK_FRAMES
		var player := get_tree().get_first_node_in_group("player") as Node3D
		_near_player = player == null or player.global_position.distance_to(global_position) < ANIMATE_RANGE
		_model.set_animating(_near_player)
	_model.animate(delta, Vector2(velocity.x, velocity.z).length())
	if direction != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(turn_speed * delta, 1.0))


func radius() -> float:
	return _radius


## Which way, and how hard, to ease out of overlaps with other living
## monsters and the player: 0 when clear, up to 1 per overlap when centred.
func _separation() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.global_position.distance_squared_to(global_position) > SEPARATION_RANGE * SEPARATION_RANGE:
		return Vector3.ZERO
	var push := Vector3.ZERO
	for other in _nearby_bodies():
		if other == self:
			continue
		var clearance: float = _radius + other.radius()
		if global_position.distance_squared_to(other.global_position) < clearance * clearance:
			push += _away_from(other.global_position, clearance)
	if player:
		push += _away_from(player.global_position, _radius + PLAYER_RADIUS)
	return push


## The visible monster bodies within SEPARATION_RANGE of the player, found
## once per physics frame and shared by every monster.
func _nearby_bodies() -> Array:
	var frame := Engine.get_physics_frames()
	if frame != _bodies_frame:
		_bodies_frame = frame
		_bodies.clear()
		var player := get_tree().get_first_node_in_group("player") as Node3D
		for body in get_tree().get_nodes_in_group("monster_bodies"):
			if body.visible and (player == null or player.global_position.distance_squared_to(body.global_position) <= SEPARATION_RANGE * SEPARATION_RANGE):
				_bodies.append(body)
	return _bodies


func _away_from(point: Vector3, clearance: float) -> Vector3:
	var offset := (global_position - point) * Vector3(1, 0, 1)
	var distance := offset.length()
	if distance >= clearance:
		return Vector3.ZERO
	if distance < 0.01:
		# Exactly on top: pick a direction from the instance so pairs split.
		offset = Vector3(1, 0, 0).rotated(Vector3.UP, float(get_instance_id() % 628) / 100.0)
		distance = 0.01
	return offset / distance * (clearance - distance) / clearance


## The next navmesh waypoint toward target. Path queries are costly, so the
## waypoint is reused until the target moves, it's reached, or a few frames pass.
func _waypoint_toward(target: Vector3) -> Vector3:
	_path_frames -= 1
	var reached := (_waypoint - global_position) * Vector3(1, 0, 1)
	if _path_frames <= 0 or target.distance_to(_path_target) > 0.5 or reached.length() < 0.3:
		_waypoint = Navigation.next_waypoint(get_world_3d(), global_position, target)
		_path_target = target
		_path_frames = PATH_REFRESH_FRAMES
	return _waypoint
