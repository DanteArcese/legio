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

const UiFocus := preload("res://scripts/input/ui_focus.gd")
const MoveMath := preload("res://scripts/player/move_math.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const Navigation := preload("res://scripts/world/navigation.gd")
const KaykitCharacter := preload("res://scripts/world/kaykit_character.gd")
const PlayerLook := preload("res://scripts/player/player_look.gd")
const WorldMenu := preload("res://scripts/player/world_menu.gd")

const CLICK_RAY_LENGTH := 300.0
## Terrain (1), monsters (4), props (8), and structures (16) can be clicked.
const CLICK_MASK := 1 | 4 | 8 | 16 | 32
## How close to walk to a clicked interactable before using it.
const CLICK_USE_DISTANCE := 1.6
const Athletics := preload("res://scripts/sim/athletics.gd")
const Circus := preload("res://scripts/sim/circus.gd")
const ChariotModel := preload("res://scripts/world/chariot_model.gd")
## Where the villa's waystone leads: the road into Portus Salis.
const WAYSTONE_DESTINATION := Vector3(-300, 0, -44)
## Fishing spots sit out in the pond; the shore is as close as you get.
const FISHING_USE_DISTANCE := 2.6

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
## An obstacle crossing being played out: {"from", "to", "elapsed", "duration", "falls", "kind"}.
var _crossing := {}
## The chariot under the player during a race.
var _chariot: Node3D
## The sim tick a stop was queued on: the target stays set until the next
## tick, and the player shouldn't walk back toward it meanwhile.
var _stop_issued_at := -1
var _look_key := "?"


func _ready() -> void:
	add_to_group("player")
	$Mesh.visible = false
	_entity.combat_moment.connect(_on_combat_moment)
	if sim_driver:
		sim_driver.sim_event.connect(_on_sim_event)


func _on_sim_event(event: Dictionary) -> void:
	if event.get("id") != _entity.entity_id:
		return
	# The sim decides where the crossing ends; snap there when it's done.
	if event["type"] == "obstacle_done":
		var done: Dictionary = sim_driver.sim.athletics.obstacles[event["obstacle"]]
		var end: Vector3 = done["end"] if event["success"] else done["start"]
		global_position = Vector3(end.x, 1.0, end.z)
		_crossing = {}
		return
	if event["type"] == "race_started":
		destination = null
		_on_arrival = {}
		global_position = event["position"] + Vector3(0, 1, 0)
		rotation.y = -PI / 2.0
		if _chariot == null:
			_chariot = ChariotModel.build(Color(0.75, 0.2, 0.18))
			_chariot.position.y = -1.0
			add_child(_chariot)
		return
	if event["type"] in ["games_started", "games_ended", "teleported"]:
		destination = null
		_on_arrival = {}
		global_position = event["position"] + Vector3(0, 1, 0)
		return
	if event["type"] == "race_ended":
		if _chariot:
			_chariot.queue_free()
			_chariot = null
		return
	if event["type"] != "obstacle_started":
		return
	var obstacle: Dictionary = sim_driver.sim.athletics.obstacles[event["obstacle"]]
	destination = null
	_on_arrival = {}
	_crossing = {"from": event["from"], "to": event["to"], "elapsed": 0.0,
		"duration": event["ticks"] * sim_driver.clock.tick_length, "falls": event["falls"],
		"kind": Athletics.obstacle_data(obstacle["course"], obstacle["index"])["kind"]}


func is_crossing() -> bool:
	return not _crossing.is_empty()


## Moves along the obstacle; a fall turns back halfway and drops you at the start.
func _play_crossing(delta: float) -> void:
	_crossing["elapsed"] += delta
	var t := clampf(_crossing["elapsed"] / maxf(_crossing["duration"], 0.01), 0.0, 1.0)
	var from: Vector3 = _crossing["from"]
	var to: Vector3 = _crossing["to"]
	var along := t
	if _crossing["falls"]:
		along = t if t < 0.5 else 1.0 - t
	var at := from.lerp(to, along)
	var lift := 0.0
	if _crossing["kind"] in ["wall", "rope", "climb"]:
		lift = sin(along * PI) * (1.2 if _crossing["kind"] == "rope" else (3.2 if _crossing["kind"] == "climb" else 1.6))
	elif _crossing["kind"] == "hurdles":
		lift = absf(sin(along * PI * 3.0)) * 0.6
	global_position = Vector3(at.x, global_position.y if lift == 0.0 else 1.0 + lift, at.z)
	velocity = Vector3.ZERO
	var facing := (to - from) * Vector3(1, 0, 1)
	if facing.length_squared() > 0.0001:
		rotation.y = atan2(-facing.x, -facing.z)
	if _model:
		_model.set_work("cross_" + _crossing["kind"])
		_model.animate(delta, 0.0)


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
	# A controller press a menu didn't use isn't meant for the world.
	if UiFocus.pad_in_menu(event, get_viewport()):
		return
	if event.is_action_pressed("run_toggle"):
		running = not running
	elif event.is_action_pressed("combat_style") and sim_driver:
		var styles: Array = Skills.styles_for(_entity.combatant.combat_kind())
		var next: String = styles[(styles.find(_entity.combatant.style) + 1) % styles.size()]
		sim_driver.sim.queue_style(_entity.entity_id, next)
	elif event.is_action_pressed("special_attack") and sim_driver:
		sim_driver.sim.queue_item_action(_entity.entity_id, "special")
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


## Opens a follow-on menu (such as a shopkeeper's wares) in the middle of
## the screen, after the menu that led here has closed.
func show_options(options: Array) -> void:
	world_menu_requested.emit.call_deferred(options, get_viewport().get_visible_rect().size / 2.0)


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
	_disengage()
	if not options.is_empty():
		options[0][1].call()
	else:
		walk_to(hit["position"])


## Walks to a point on the ground, dropping combat and skilling on the way
## (a plain click on the ground).
func walk_here(point: Vector3) -> void:
	_disengage()
	walk_to(point)


## Stops fighting and skilling. The sim clears the target on its next tick;
## until then, don't walk back toward it.
func _disengage() -> void:
	var id: int = _entity.entity_id
	sim_driver.sim.queue_stop(id)
	sim_driver.sim.queue_item_action(id, "stop_action")
	_stop_issued_at = sim_driver.sim.tick


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
	_stop_issued_at = -1
	destination = null
	_on_arrival = {}
	sim_driver.sim.queue_attack(_entity.entity_id, entity_id)


func mine(rock: Node3D) -> void:
	walk_and_do(rock.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "mine", {"rock": rock.rock_id}))


func chop(tree: Node3D) -> void:
	walk_and_do(tree.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "chop", {"tree": tree.tree_id}))


func fish(spot: Node3D) -> void:
	walk_and_do(spot.global_position, FISHING_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "fish", {"spot": spot.spot_id}))


func talk(npc: Node3D) -> void:
	walk_and_do(npc.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "talk", {"npc": npc.get_meta("npc_id")}))


func buy_villa(surveyor: Node3D) -> void:
	walk_and_do(surveyor.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "buy_villa"))


func build_furniture(hotspot: Node3D, furniture_id: String) -> void:
	walk_and_do(hotspot.global_position, CLICK_USE_DISTANCE + 0.6, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "build", {"hotspot": hotspot.hotspot_id, "furniture": furniture_id,
			"now": Time.get_unix_time_from_system()}))


func rest_at(hotspot: Node3D) -> void:
	walk_and_do(hotspot.global_position, CLICK_USE_DISTANCE + 0.6, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "rest", {"hotspot": hotspot.hotspot_id}))


func remove_furniture(hotspot: Node3D) -> void:
	walk_and_do(hotspot.global_position, CLICK_USE_DISTANCE + 0.6, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "remove_furniture", {"hotspot": hotspot.hotspot_id}))


## The villa's steward hands over what the presses made, by real time.
func collect_estate(steward: Node3D) -> void:
	walk_and_do(steward.global_position, CLICK_USE_DISTANCE + 0.6, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "collect_estate", {"now": Time.get_unix_time_from_system()}))


## The villa's waystone: straight down the road to Portus Salis.
func use_waystone(stone: Node3D) -> void:
	walk_and_do(stone.global_position, CLICK_USE_DISTANCE, func():
		var id: int = _entity.entity_id
		sim_driver.sim.queue_stop(id)
		sim_driver.sim.queue_item_action(id, "stop_action")
		global_position = WAYSTONE_DESTINATION + Vector3(0, 1, 0)
		sim_driver.sim.set_position(id, WAYSTONE_DESTINATION))


func take_contract(board: Node3D, contract_id: String) -> void:
	walk_and_do(board.global_position, CLICK_USE_DISTANCE + 0.4, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "take_contract", {"board": board.board_id, "contract": contract_id}))


func abandon_contract() -> void:
	sim_driver.sim.queue_item_action(_entity.entity_id, "abandon_contract")


func deliver_contract(shopkeeper: Node3D) -> void:
	walk_and_do(shopkeeper.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "deliver_contract", {"shop": shopkeeper.get_meta("shop_id")}))


func farm(patch: Node3D, seed := "") -> void:
	walk_and_do(patch.global_position, CLICK_USE_DISTANCE + 0.6, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "farm", {"patch": patch.patch_id, "seed": seed}))


func use_trap_spot(spot: Node3D) -> void:
	walk_and_do(spot.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "trap", {"spot": spot.spot_id}))


func cross(obstacle: Node3D) -> void:
	walk_and_do(obstacle.global_position, 1.2, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "obstacle", {"obstacle": obstacle.obstacle_id}))


func crack(box: Node3D) -> void:
	walk_and_do(box.global_position, CLICK_USE_DISTANCE + 0.4, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "crack", {"strongbox": box.strongbox_id}))


func steal(stall: Node3D) -> void:
	walk_and_do(stall.global_position, CLICK_USE_DISTANCE + 0.4, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "steal", {"stall": stall.stall_id}))


func pickpocket(mark: Node3D) -> void:
	walk_and_do(mark.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "pickpocket", {"mark": mark.get_meta("mark_id")}))


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


func slayer_reward(venator: Node3D, reward: String, args := {}) -> void:
	var command := args.duplicate()
	command["venator"] = venator.get_meta("venator_id")
	command["reward"] = reward
	walk_and_do(venator.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "slayer_reward", command))


## Takes one item kind from a pile, or everything if item_id is "".
func take(pile: Node3D, item_id := "") -> void:
	var args := {"pile": pile.pile_id}
	if not item_id.is_empty():
		args["item"] = item_id
	walk_and_do(pile.global_position, 0.8, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "pickup", args))


func pick_up_pet() -> void:
	sim_driver.sim.queue_item_action(_entity.entity_id, "pickup_pet")


func loot_grave(grave: Node3D) -> void:
	walk_and_do(grave.global_position, 0.8, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "loot_grave"))


func travel(doorway: Node3D) -> void:
	walk_and_do(doorway.global_position, 1.9, _arrive_through.bind(doorway))


func ride_post(station: Node3D, to: String) -> void:
	walk_and_do(station.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "waystation_travel", {"to": to}))


func buy(shopkeeper: Node3D, item_id: String) -> void:
	walk_and_do(shopkeeper.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "buy", {"shop": shopkeeper.get_meta("shop_id"), "item": item_id}))


## The editor sends you out onto the sand for the munera.
func start_games(editor: Node3D) -> void:
	walk_and_do(editor.global_position, CLICK_USE_DISTANCE + 0.6, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "start_games"))


## The factio agent enters you in a chariot race.
func start_race(agent: Node3D) -> void:
	walk_and_do(agent.global_position, CLICK_USE_DISTANCE + 0.6, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "start_race"))


func take_arena(lanista: Node3D, contract_id: String) -> void:
	walk_and_do(lanista.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "take_arena", {"contract": contract_id}))


func hand_in_arena(lanista: Node3D) -> void:
	walk_and_do(lanista.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "hand_in_arena"))


func abandon_arena() -> void:
	sim_driver.sim.queue_item_action(_entity.entity_id, "abandon_arena")


## Walks up to a weakened beast and throws a net over it.
func capture(monster: Node) -> void:
	var body: Node3D = monster.body()
	walk_and_do(body.global_position, 2.2, func():
		sim_driver.sim.queue_stop(_entity.entity_id)
		sim_driver.sim.queue_item_action(_entity.entity_id, "capture", {"target": monster.entity_id}))


func sell(shopkeeper: Node3D, item_id: String) -> void:
	walk_and_do(shopkeeper.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "sell", {"shop": shopkeeper.get_meta("shop_id"), "item": item_id}))


func _arrive_through(doorway: Node3D) -> void:
	if not doorway.warning.is_empty() and not doorway.warned:
		doorway.warned = true
		message_requested.emit(doorway.warning)
		return
	var id: int = _entity.entity_id
	if doorway.requires_villa and not _entity.combatant.villa_owned:
		message_requested.emit("That's private land. The land surveyor in the forum sells villas to citizens.")
		return
	if not doorway.requires_quest.is_empty() and not _entity.combatant.quests.get(doorway.requires_quest, {}).get("done", false):
		message_requested.emit(doorway.locked_message if not doorway.locked_message.is_empty() else "That way is shut to you for now.")
		return
	if doorway.fare > 0:
		if _entity.combatant.inventory.count("coins") < doorway.fare:
			message_requested.emit("The ferryman wants %d denarii for the crossing." % doorway.fare)
			return
		sim_driver.sim.queue_item_action(id, "pay_fare", {"amount": doorway.fare})
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


func wash(spring: Node3D) -> void:
	# The spring's centre is in the water; walk to its edge nearest us.
	var edge: Vector3 = spring.global_position + _flat(global_position - spring.global_position).normalized() * 4.6
	walk_and_do(edge, 0.8, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "wash"))


func cleanse(priest: Node3D) -> void:
	walk_and_do(priest.global_position, CLICK_USE_DISTANCE, func():
		sim_driver.sim.queue_item_action(_entity.entity_id, "cleanse"))


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
	var spot := _nearest_in_group("fishing_spots", FISHING_USE_DISTANCE + 0.4)
	if spot:
		sim_driver.sim.queue_item_action(id, "fish", {"spot": spot.spot_id})
		return
	if _near_any("springs", 6.0):
		sim_driver.sim.queue_item_action(id, "wash")
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
	var tree := _nearest_in_group("trees", grave_radius + 0.4)
	if tree:
		sim_driver.sim.queue_item_action(id, "chop", {"tree": tree.tree_id})
		return
	var patch := _nearest_in_group("patches", grave_radius + 0.6)
	if patch:
		var seeds: Array = sim_driver.sim.farming.plantable_seeds(_entity.combatant, patch.patch_id)
		sim_driver.sim.queue_item_action(id, "farm", {"patch": patch.patch_id, "seed": seeds[0] if not seeds.is_empty() else ""})
		return
	var hunt_spot := _nearest_in_group("hunt_spots", grave_radius + 0.4)
	if hunt_spot:
		sim_driver.sim.queue_item_action(id, "trap", {"spot": hunt_spot.spot_id})
		return
	var obstacle := _nearest_in_group("obstacles", 1.8)
	if obstacle:
		sim_driver.sim.queue_item_action(id, "obstacle", {"obstacle": obstacle.obstacle_id})
		return
	var stall := _nearest_in_group("stalls", grave_radius + 0.4)
	if stall:
		sim_driver.sim.queue_item_action(id, "steal", {"stall": stall.stall_id})
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
	var npc := _nearest_in_group("quest_npcs", bank_radius)
	if npc:
		sim_driver.sim.queue_item_action(id, "talk", {"npc": npc.get_meta("npc_id")})
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
	if is_crossing():
		_play_crossing(delta)
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Typing in a text box (the bank search) mustn't walk the player about.
	if get_viewport().gui_get_focus_owner() is LineEdit:
		input = Vector2.ZERO
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
	# Stunned after a failed pickpocket: rooted to the spot.
	if _entity.combatant and sim_driver and _entity.combatant.stunned_until > sim_driver.sim.tick:
		speed = 0.0
	if running and _entity.combatant and _entity.combatant.skills:
		speed *= 1.0 + Athletics.run_speed_bonus(_entity.combatant.skills.level("athletics"))
	if running and _entity.combatant:
		speed *= 1.0 + _entity.combatant.blessing_boosts.get("run_speed", 0.0)
	# In a race the horses set the pace, held back until the start.
	if _entity.combatant and Circus.is_racing(_entity.combatant):
		var race: Dictionary = _entity.combatant.race
		speed = 0.0 if sim_driver.sim.tick < race["start"] else Circus.chariot_speed(_entity.combatant.skills.level("athletics"))

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
	var work: String = action.get("kind", action.get("type", "")) if not action.is_empty() else ""
	_model.set_work(work)
	if _model is KaykitCharacter:
		_model.hold_tool(KaykitCharacter.TOOLS.get(work, ""))
	# A charioteer stands braced in the car rather than running.
	var racing: bool = _entity.combatant != null and Circus.is_racing(_entity.combatant)
	_model.animate(delta, 0.0 if racing else Vector2(velocity.x, velocity.z).length())

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
	if target_position == null or (_stop_issued_at >= 0 and sim_driver.sim.tick <= _stop_issued_at):
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
