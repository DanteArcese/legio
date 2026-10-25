extends CharacterBody3D
## The player character.
##
## Controller / WASD: the left stick moves relative to the camera, and
## Interact picks up nearby loot, loots your grave, mines a rock, uses a
## crafting station, opens a bank, talks to the libitinarius or a venator,
## or targets the nearest enemy, in that order.
##
## Mouse: left-click the ground to walk there, a monster to attack it, or
## anything interactable to walk up and use it. Paths follow the navigation
## mesh, and so does the automatic walk into reach of a combat target.
##
## Right-click (or Y on a controller) opens a menu of everything you can do
## with what's under the cursor (or, on a controller, what's nearby).

signal bank_opened
signal station_opened(station: Node)
## Options are [label, Callable] pairs; at is a screen position.
signal world_menu_requested(options: Array, at: Vector2)
signal message_requested(text: String)

const MoveMath := preload("res://scripts/player/move_math.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const Navigation := preload("res://scripts/world/navigation.gd")
const KaykitCharacter := preload("res://scripts/world/kaykit_character.gd")
const PlayerLook := preload("res://scripts/player/player_look.gd")
const WorldMenu := preload("res://scripts/player/world_menu.gd")

const CLICK_RAY_LENGTH := 300.0
## Terrain (1), monsters (4), props (8), and structures (16) can be clicked.
const CLICK_MASK := 1 | 4 | 8 | 16
## How close to walk to a clicked interactable before using it.
const CLICK_USE_DISTANCE := 1.6

@export var walk_speed := 3.0
@export var run_speed := 6.0
@export var turn_speed := 12.0
@export var target_radius := 8.0
@export var pickup_radius := 2.0
@export var bank_radius := 2.5
@export var grave_radius := 1.8
@export var camera_rig: Node3D
@export var sim_driver: Node

var running := true
## Click-to-move destination, or null.
var destination: Variant = null
## What to do on arrival: {"at": Vector3, "distance": float, "action": Callable}.
var _on_arrival := {}

@onready var _entity: Node = $SimEntity

var _model: Node3D
var _look_key := "?"


func _ready() -> void:
	add_to_group("player")
	$Mesh.visible = false
	_entity.combat_moment.connect(_on_combat_moment)


func has_animated_model() -> bool:
	return _model is KaykitCharacter


## Rebuilds the character when what's worn changes.
func _refresh_look() -> void:
	var combatant: RefCounted = _entity.combatant
	if combatant == null:
		return
	var key := PlayerLook.key(combatant.equipment.worn)
	if key == _look_key:
		return
	_look_key = key
	var was_dead: bool = _model is KaykitCharacter and _model.is_dead()
	if _model:
		_model.queue_free()
	_model = KaykitCharacter.create(PlayerLook.appearance(combatant.equipment.worn))
	# The body's origin is at its centre (capsule), the model's at its feet.
	_model.position.y = -1.0
	add_child(_model)
	if was_dead:
		_model.die()


func _on_combat_moment(moment: String, info: Dictionary) -> void:
	if not _model is KaykitCharacter:
		return
	match moment:
		"attack":
			_model.attack(info.get("kind", "") if info.get("kind", "") == "ritus" else "")
		"hurt":
			_model.hurt()
		"die":
			_model.die()
		"revive":
			_model.revive()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("run_toggle"):
		running = not running
	elif event.is_action_pressed("combat_style") and sim_driver:
		var styles: Array = Skills.styles_for(_entity.combatant.combat_kind())
		var next: String = styles[(styles.find(_entity.combatant.style) + 1) % styles.size()]
		sim_driver.sim.queue_style(_entity.entity_id, next)
	elif event.is_action_pressed("interact") and sim_driver:
		interact()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and sim_driver:
		click(event.position)
	elif event.is_action_pressed("context_menu") and sim_driver:
		if event is InputEventMouseButton:
			open_menu_at(event.position)
		else:
			open_menu_nearby()


## Right-click: options for whatever is under the cursor, plus Walk here.
func open_menu_at(screen_position: Vector2) -> void:
	var hit := _raycast(screen_position)
	if hit.is_empty():
		return
	var options := WorldMenu.options_for_hit(self, hit)
	options.append(["Walk here", walk_to.bind(hit["position"])])
	options.append(["Cancel", func(): pass])
	world_menu_requested.emit(options, screen_position)


## Controller Y: options for everything within reach, nearest first.
func open_menu_nearby() -> void:
	var options := WorldMenu.options_nearby(self)
	if options.is_empty():
		message_requested.emit("There's nothing nearby.")
		return
	options.append(["Cancel", func(): pass])
	world_menu_requested.emit(options, get_viewport().get_visible_rect().size / 2.0)


func _raycast(screen_position: Vector2) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * CLICK_RAY_LENGTH
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, CLICK_MASK, [get_rid()]))


## Handles a left-click at a screen position: the first menu option for
## what was clicked, or walking there for plain ground.
func click(screen_position: Vector2) -> void:
	var hit := _raycast(screen_position)
	if hit.is_empty():
		return
	var options := WorldMenu.options_for_hit(self, hit)
	if not options.is_empty() and not WorldMenu.is_ground(hit["collider"]):
		options[0][1].call()
		return
	# Ground: walk there, cancelling combat and skilling. Clicking right next
	# to loot or your grave uses it on arrival.
	var id: int = _entity.entity_id
	sim_driver.sim.queue_stop(id)
	sim_driver.sim.queue_item_action(id, "stop_action")
	if not options.is_empty():
		options[0][1].call()
	else:
		walk_to(hit["position"])


## Walks along the navigation mesh to a point.
func walk_to(point: Vector3) -> void:
	destination = point
	_on_arrival = {}


## Walks up to something and then does action once within distance of it.
func walk_and_do(at: Vector3, distance: float, action: Callable) -> void:
	if _flat(at - global_position).length() <= distance:
		destination = null
		_on_arrival = {}
		action.call()
		return
	destination = Navigation.closest_walkable(get_world_3d(), at)
	_on_arrival = {"at": at, "distance": distance, "action": action}


# --- Precise actions (used by menus, clicks, and Interact) ---------------

func attack(entity_id: int) -> void:
	destination = null
	_on_arrival = {}
	sim_driver.sim.queue_attack(_entity.entity_id, entity_id)


func mine(rock: Node3D) -> void:
	walk_and_do(rock.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "mine", {"rock": rock.rock_id}))


func use_station(station: Node3D) -> void:
	walk_and_do(station.global_position, CLICK_USE_DISTANCE, station_opened.emit.bind(station))


func open_bank(chest: Node3D) -> void:
	walk_and_do(chest.global_position, CLICK_USE_DISTANCE, bank_opened.emit)


func reclaim(undertaker: Node3D) -> void:
	walk_and_do(undertaker.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "reclaim"))


func ask_for_contract(venator: Node3D) -> void:
	walk_and_do(venator.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "slayer_task", {"venator": venator.get_meta("venator_id")}))


## Takes one item kind from a pile, or everything if item_id is "".
func take(pile: Node3D, item_id := "") -> void:
	var args := {"pile": pile.pile_id}
	if not item_id.is_empty():
		args["item"] = item_id
	walk_and_do(pile.global_position, 0.8, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "pickup", args))


func loot_grave(grave: Node3D) -> void:
	walk_and_do(grave.global_position, 0.8, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "loot_grave"))


func travel(doorway: Node3D) -> void:
	walk_and_do(doorway.global_position, 1.9, _arrive_through.bind(doorway))


func buy(shopkeeper: Node3D, item_id: String) -> void:
	walk_and_do(shopkeeper.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "buy", {"shop": shopkeeper.get_meta("shop_id"), "item": item_id}))


func _arrive_through(doorway: Node3D) -> void:
	var id: int = _entity.entity_id
	sim_driver.sim.queue_stop(id)
	sim_driver.sim.queue_item_action(id, "stop_action")
	destination = null
	_on_arrival = {}
	velocity = Vector3.ZERO
	global_position = doorway.destination + Vector3(0, 1, 0)
	sim_driver.sim.set_position(id, doorway.destination)


func pray(altar: Node3D) -> void:
	walk_and_do(altar.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "pray"))


func offer(altar: Node3D, item_id: String) -> void:
	walk_and_do(altar.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "offer", {"item": item_id}))


func examine(text: String) -> void:
	message_requested.emit(text)


func interact() -> void:
	var id: int = _entity.entity_id
	var pile: Node3D = sim_driver.nearest_pile(global_position, pickup_radius, _entity.combatant.inventory)
	if pile:
		sim_driver.sim.queue_item_action(id, "pickup", {"pile": pile.pile_id})
		return
	if _near_any("graves", grave_radius):
		sim_driver.sim.queue_item_action(id, "loot_grave")
		return
	if _near_any("altars", bank_radius):
		sim_driver.sim.queue_item_action(id, "pray")
		return
	var doorway := _nearest_in_group("transitions", 2.0)
	if doorway:
		_arrive_through(doorway)
		return
	var rock := _nearest_in_group("rocks", grave_radius + 0.4)
	if rock:
		sim_driver.sim.queue_item_action(id, "mine", {"rock": rock.rock_id})
		return
	var station := _nearest_in_group("stations", grave_radius + 0.4)
	if station:
		station_opened.emit(station)
		return
	if _near_any("banks", bank_radius):
		bank_opened.emit()
		return
	if _near_any("libitinarii", bank_radius):
		sim_driver.sim.queue_item_action(id, "reclaim")
		return
	for venator in get_tree().get_nodes_in_group("venatores"):
		if global_position.distance_to(venator.global_position) <= bank_radius:
			sim_driver.sim.queue_item_action(id, "slayer_task", {"venator": venator.get_meta("venator_id")})
			return
	var target_id: int = sim_driver.nearest_target(id, target_radius)
	if target_id == -1:
		sim_driver.sim.queue_stop(id)
	else:
		sim_driver.sim.queue_attack(id, target_id)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw := camera_rig.global_rotation.y if camera_rig else 0.0
	var direction := MoveMath.camera_relative(input, yaw)
	var face_target := false
	if direction != Vector3.ZERO:
		destination = null
		_on_arrival = {}
	elif destination != null:
		direction = _destination_direction()
	else:
		var approach := _approach_direction()
		direction = approach
		face_target = approach == Vector3.ZERO and _target_position() != null
	var speed := run_speed if running else walk_speed
	if running and _entity.combatant:
		speed *= 1.0 + _entity.combatant.blessing_boosts.get("run_speed", 0.0)

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	_entity.rescue_if_fallen()
	_refresh_look()
	if _model == null:
		return
	var action: Dictionary = _entity.combatant.skill_action if _entity.combatant else {}
	_model.set_work(action.get("kind", action.get("type", "")) if not action.is_empty() else "")
	_model.animate(delta, Vector2(velocity.x, velocity.z).length())

	var facing := direction
	if face_target:
		facing = (_target_position() - global_position) * Vector3(1, 0, 1)
	if facing.length_squared() > 0.0001:
		var target_yaw := atan2(-facing.x, -facing.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(turn_speed * delta, 1.0))


func _near_any(group: String, radius: float) -> bool:
	return _nearest_in_group(group, radius) != null


func _nearest_in_group(group: String, radius: float) -> Node3D:
	var best: Node3D = null
	var best_distance := radius
	for node in get_tree().get_nodes_in_group(group):
		var offset: Vector3 = (node.global_position - global_position) * Vector3(1, 0, 1)
		if offset.length() <= best_distance:
			best = node
			best_distance = offset.length()
	return best


## Direction along the path to the click destination. Arriving stops and
## runs the pending action, if any.
func _destination_direction() -> Vector3:
	var arrived := _flat(destination - global_position).length() <= 0.3
	if not _on_arrival.is_empty():
		arrived = arrived or _flat(_on_arrival["at"] - global_position).length() <= _on_arrival["distance"]
	if arrived:
		var action: Variant = _on_arrival.get("action")
		destination = null
		_on_arrival = {}
		if action:
			action.call()
		return Vector3.ZERO
	var step := _flat(Navigation.next_waypoint(get_world_3d(), global_position, destination) - global_position)
	if step.length() < 0.01:
		destination = null
		_on_arrival = {}
		return Vector3.ZERO
	return step.normalized()


## Direction along the path toward the current target while out of reach,
## otherwise zero.
func _approach_direction() -> Vector3:
	var target_position: Variant = _target_position()
	if target_position == null:
		return Vector3.ZERO
	if _flat(target_position - global_position).length() <= _entity.combatant.attack_range() * 0.9:
		return Vector3.ZERO
	var step := _flat(Navigation.next_waypoint(get_world_3d(), global_position, target_position) - global_position)
	return step.normalized() if step.length() > 0.01 else Vector3.ZERO


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _target_position() -> Variant:
	if not sim_driver or not _entity.combatant:
		return null
	var target: RefCounted = sim_driver.sim.get_combatant(_entity.combatant.target_id)
	return target.position if target else null
