extends Node
## Links a scene body (this node's parent) to a combatant in the simulation.
## Monsters take their stats from content via monster_id; other entities
## (the player, the training dummy) are configured with the exports below.

const HitSplat := preload("res://scripts/world/hit_splat.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

## 0 means the driver assigns an id.
@export var entity_id := 0
## Content id of a monster. When set, the stats below are ignored.
@export var monster_id := ""
@export var max_hp := 10
@export var attack_level := 1
@export var strength_level := 1
@export var defence_level := 1
@export var attack_speed := 4
@export var reach := 1.5
@export var can_fight := true
@export var auto_retaliate := true
@export var respawn_ticks := -1
## Whether the player can target this entity.
@export var attackable := true
@export var hp_label: Label3D
## Players get skills, an inventory, equipment, a bank, and the starting kit.
@export var is_player := false

var combatant: RefCounted
var spawn_position := Vector3.ZERO


func body() -> Node3D:
	return get_parent()


## Creates this entity's combatant in the simulation.
func register(sim: RefCounted) -> void:
	spawn_position = body().global_position
	if not monster_id.is_empty():
		combatant = sim.add_monster(entity_id, monster_id, spawn_position)
	elif is_player:
		combatant = sim.add_player(entity_id, spawn_position)
		combatant.reach = reach
		combatant.respawn_ticks = respawn_ticks
		sim.give_starting_kit(entity_id)
	else:
		combatant = sim.add_combatant(entity_id)
		combatant.max_hp = max_hp
		combatant.hp = max_hp
		combatant.levels = {"attack": attack_level, "strength": strength_level, "defence": defence_level}
		combatant.attack_speed = attack_speed
		combatant.reach = reach
		combatant.can_fight = can_fight
		combatant.auto_retaliate = auto_retaliate
		combatant.respawn_ticks = respawn_ticks
	_update_label()


func display_name() -> String:
	return ContentDB.monster(monster_id)["name"] if not monster_id.is_empty() else String(body().name).capitalize()


func on_sim_event(event: Dictionary) -> void:
	match event["type"]:
		"hit":
			if event["target"] == entity_id:
				HitSplat.spawn(body(), event["damage"])
		"death":
			if event["id"] == entity_id:
				body().visible = false
		"respawn":
			if event["id"] == entity_id:
				place_on_ground(spawn_position)
				body().visible = true
	_update_label()


## Puts the body on the ground above or below a position (terrain may sit
## higher than the spawn point that was saved).
func place_on_ground(at: Vector3) -> void:
	var space := body().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(at + Vector3(0, 40, 0), at - Vector3(0, 40, 0), 1)
	var hit := space.intersect_ray(query)
	var ground: Vector3 = hit["position"] if not hit.is_empty() else at
	var feet_offset := 1.0 if is_player else 0.05
	body().global_position = ground + Vector3(0, feet_offset, 0)
	if body() is CharacterBody3D:
		body().velocity = Vector3.ZERO


## Safety net: anything that falls out of the world goes back to its spawn.
func rescue_if_fallen() -> void:
	if body().global_position.y < -30.0 and body().global_position.x < 100.0:
		place_on_ground(spawn_position)


func _update_label() -> void:
	if hp_label and combatant:
		var title := ""
		if not monster_id.is_empty():
			title = "%s (level %d)\n" % [display_name(), combatant.display_level]
		hp_label.text = "%s%d / %d" % [title, combatant.hp, combatant.max_hp]
