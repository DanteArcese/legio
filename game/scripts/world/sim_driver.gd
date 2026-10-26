extends Node
## Runs the simulation on game ticks and relays its events to the scene.
## Press F3 to cycle tick lengths (debug only; the game uses 0.6 s).

const Simulation := preload("res://scripts/sim/simulation.gd")
const TickClock := preload("res://scripts/sim/tick_clock.gd")
const LootPile := preload("res://scripts/world/loot_pile.gd")
const GraveMarker := preload("res://scripts/world/grave_marker.gd")
const Projectile := preload("res://scripts/world/projectile.gd")
const CurseVisuals := preload("res://scripts/world/curse_visuals.gd")
const CURSE_TINTS := {"binding": Color(0.1, 0.06, 0.16), "withering": Color(0.12, 0.14, 0.06),
	"silencing": Color(0.1, 0.16, 0.3), "manes": Color(0.2, 0.3, 0.45)}
const ShadeBody := preload("res://scripts/world/shade_body.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

## Entities with entity_id 0 get ids from here up.
const AUTO_ID_START := 1000

signal ticked(tick: int)
signal sim_event(event: Dictionary)

@export var seed_value := 0
@export var tick_lengths: Array[float] = [0.6, 0.5, 0.4]

var sim: Simulation
var clock := TickClock.new()

var _entities := {}
var _next_auto_id := AUTO_ID_START
var _piles := {}
var _graves := {}
var _rocks := {}
var _trees := {}
var _stalls := {}
var _hunt_spots := {}
var _patches := {}
var _shades := {}


func _ready() -> void:
	sim = Simulation.new(seed_value)
	clock.tick_length = tick_lengths[0]
	for entity in get_tree().get_nodes_in_group("sim_entities"):
		register(entity)
	for bank in get_tree().get_nodes_in_group("banks"):
		sim.add_bank(bank.global_position)
	for zone in get_tree().get_nodes_in_group("danger_zones"):
		sim.add_danger_zone(zone.danger_area)
	for undertaker in get_tree().get_nodes_in_group("libitinarii"):
		sim.add_libitinarius(undertaker.global_position)
	for venator in get_tree().get_nodes_in_group("venatores"):
		sim.add_venator(venator.get_meta("venator_id"), venator.global_position)
	for altar in get_tree().get_nodes_in_group("altars"):
		sim.pietas.add_altar(altar.kind, altar.global_position)
	for npc in get_tree().get_nodes_in_group("quest_npcs"):
		sim.quests.add_npc(npc.get_meta("npc_id"), npc.global_position)
	for shopkeeper in get_tree().get_nodes_in_group("shopkeepers"):
		sim.add_shopkeeper(shopkeeper.get_meta("shop_id"), shopkeeper.global_position)
		if shopkeeper.get_meta("shop_id") == "sacerdos":
			sim.pietas.set_priest(shopkeeper.global_position)
	# Springs are built by the terrain after this runs.
	_register_springs.call_deferred()
	for rock in get_tree().get_nodes_in_group("rocks"):
		rock.rock_id = _rocks.size() + 1
		_rocks[rock.rock_id] = rock
		sim.skilling.add_rock(rock.rock_id, rock.rock_type, rock.global_position)
	for tree in get_tree().get_nodes_in_group("trees"):
		tree.tree_id = _trees.size() + 1
		_trees[tree.tree_id] = tree
		sim.skilling.add_tree(tree.tree_id, tree.tree_type, tree.global_position)
	var spot_id := 0
	for spot in get_tree().get_nodes_in_group("fishing_spots"):
		spot_id += 1
		spot.spot_id = spot_id
		sim.skilling.add_fishing_spot(spot_id, spot.spot_type, spot.global_position)
	for board in get_tree().get_nodes_in_group("trade_boards"):
		sim.mercatura.add_board(board.board_id, board.global_position)
	for patch in get_tree().get_nodes_in_group("patches"):
		patch.patch_id = _patches.size() + 1
		_patches[patch.patch_id] = patch
		sim.farming.add_patch(patch.patch_id, patch.patch_type, String(patch.name), patch.global_position)
	for spot in get_tree().get_nodes_in_group("hunt_spots"):
		spot.spot_id = _hunt_spots.size() + 1
		_hunt_spots[spot.spot_id] = spot
		sim.hunter.add_spot(spot.spot_id, spot.spot_type, spot.global_position)
	var obstacle_id := 0
	for obstacle in get_tree().get_nodes_in_group("obstacles"):
		obstacle_id += 1
		obstacle.obstacle_id = obstacle_id
		sim.athletics.add_obstacle(obstacle_id, obstacle.course, obstacle.index, obstacle.global_position, obstacle.end_position())
	for stall in get_tree().get_nodes_in_group("stalls"):
		stall.stall_id = _stalls.size() + 1
		_stalls[stall.stall_id] = stall
		sim.thieving.add_stall(stall.stall_id, stall.stall_type, stall.global_position)
	var mark_id := 0
	for mark in get_tree().get_nodes_in_group("marks"):
		mark_id += 1
		mark.set_meta("mark_id", mark_id)
		sim.thieving.add_mark(mark_id, mark.get_meta("mark_type"), mark.global_position)
	for station in get_tree().get_nodes_in_group("stations"):
		sim.skilling.add_station(station.kind, station.global_position)


func _register_springs() -> void:
	for spring in get_tree().get_nodes_in_group("springs"):
		sim.pietas.add_spring(spring.global_position)


func register(entity: Node) -> void:
	if entity.entity_id == 0:
		entity.entity_id = _next_auto_id
		_next_auto_id += 1
	entity.register(sim)
	_entities[entity.entity_id] = entity


func entity(id: int) -> Node:
	return _entities.get(id)


## Nearest living, attackable entity to from_id within max_distance, or -1.
func nearest_target(from_id: int, max_distance: float) -> int:
	var origin: Vector3 = _entities[from_id].body().global_position
	var best_id := -1
	var best_distance := max_distance
	for id in _entities:
		var entity: Node = _entities[id]
		if id == from_id or not entity.attackable or not entity.combatant.is_alive():
			continue
		var distance := origin.distance_to(entity.body().global_position)
		if distance <= best_distance:
			best_id = id
			best_distance = distance
	return best_id


func _physics_process(delta: float) -> void:
	for i in clock.advance(delta):
		for id in _entities:
			sim.set_position(id, _entities[id].body().global_position)
		for event in sim.step():
			for entity in _entities.values():
				entity.on_sim_event(event)
			_mirror_ground(event)
			sim_event.emit(event)
		ticked.emit(sim.tick)


## Mirrors and broadcasts an event that didn't come from step(), such as
## state restored from a save.
func replay_event(event: Dictionary) -> void:
	_mirror_ground(event)
	sim_event.emit(event)


## Nearest ground pile within range of a position, or null. With an
## inventory, piles with nothing that fits are skipped.
func nearest_pile(origin: Vector3, max_distance: float, inventory: RefCounted = null) -> Node3D:
	var best: Node3D = null
	var best_distance := max_distance
	for pile in _piles.values():
		if inventory and not pile.items.any(func(e): return inventory.space_for(e["item"], e["quantity"]) > 0):
			continue
		var distance := origin.distance_to(pile.global_position)
		if distance <= best_distance:
			best = pile
			best_distance = distance
	return best


func _mirror_ground(event: Dictionary) -> void:
	match event["type"]:
		"summon":
			_shades[event["id"]] = ShadeBody.spawn(get_parent(), self, event["id"], event["position"])
		"summon_end":
			var shade: Node = _shades.get(event["id"])
			if shade:
				shade.fade_out()
				_shades.erase(event["id"])
		"hit":
			if _shades.has(event["attacker"]):
				_shades[event["attacker"]].attack()
			if event.get("ranged", false):
				_shoot(event)
			elif event.get("kind", "") == "ritus":
				var target: Node = _entities.get(event["target"])
				if target:
					CurseVisuals.puff(get_parent(), target.body().global_position + Vector3(0, 1.0, 0))
		"curse":
			var cursed: Node = _entities.get(event["id"])
			if cursed:
				var seconds: float = maxi(event["until"] - event["tick"], 1) * clock.tick_length
				CurseVisuals.aura(cursed.body(), seconds, CURSE_TINTS.get(event["curse"], Color.BLACK))
		"ground_add":
			_piles[event["pile"]] = LootPile.spawn(get_parent(), event["pile"], event["position"], event["items"])
		"ground_update":
			_piles[event["pile"]].set_items(event["items"])
		"rock_depleted", "rock_respawned":
			_rocks[event["rock"]].set_depleted(event["type"] == "rock_depleted")
		"patch_changed":
			_patches[event["patch"]].show_crop(event["crop"], event["stage"], event["ready"])
		"trap_set":
			_hunt_spots[event["spot"]].set_trap_state("set")
		"trap_caught":
			_hunt_spots[event["spot"]].set_trap_state("caught")
		"trap_cleared":
			_hunt_spots[event["spot"]].set_trap_state("")
		"stall_emptied", "stall_restocked":
			_stalls[event["stall"]].set_empty(event["type"] == "stall_emptied")
		"tree_felled", "tree_regrown":
			_trees[event["tree"]].set_felled(event["type"] == "tree_felled")
		"grave_add":
			_graves[event["grave"]] = GraveMarker.spawn(get_parent(), self, event["position"], event["expires_at"])
		"grave_remove":
			var marker: Node = _graves.get(event["grave"])
			if marker:
				marker.queue_free()
				_graves.erase(event["grave"])
		"ground_remove":
			var pile: Node = _piles.get(event["pile"])
			if pile:
				pile.queue_free()
				_piles.erase(event["pile"])


func _shoot(event: Dictionary) -> void:
	var attacker: Node = _entities.get(event["attacker"])
	var target: Node = _entities.get(event["target"])
	if attacker == null or target == null:
		return
	var weapon: Dictionary = attacker.combatant.equipment.weapon() if attacker.combatant.equipment else {}
	var up := Vector3(0, 0.4, 0)
	Projectile.spawn(get_parent(), attacker.body().global_position + up, target.body().global_position + up, weapon.get("ammo", "arrow"))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		var next := (tick_lengths.find(clock.tick_length) + 1) % tick_lengths.size()
		clock.tick_length = tick_lengths[next]
