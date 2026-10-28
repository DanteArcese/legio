extends Node
## Links a scene body (this node's parent) to a combatant in the simulation.
## Monsters take their stats from content via monster_id; other entities
## (the player, the training dummy) are configured with the exports below.

const LevelColors := preload("res://scripts/ui/level_colors.gd")
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

## Combat moments for the body's model to animate: "attack", "hurt",
## "die", "revive". info carries the attack kind.
signal combat_moment(moment: String, info: Dictionary)

## Animated models play their death before the body disappears.
const DEATH_HIDE_DELAY := 1.6
@export var is_player := false
## A label quests can point at (e.g. "training_dummy").
@export var tag := ""

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
	combatant.tag = tag
	_update_label()


func display_name() -> String:
	return ContentDB.monster(monster_id)["name"] if not monster_id.is_empty() else String(body().name).capitalize()


func on_sim_event(event: Dictionary) -> void:
	match event["type"]:
		"hit":
			if event["target"] == entity_id:
				HitSplat.spawn(body(), event["damage"])
				if event["damage"] > 0:
					combat_moment.emit("hurt", event)
			if event["attacker"] == entity_id and event.get("kind", "") != "withering":
				combat_moment.emit("attack", event)
		"death":
			if event["id"] == entity_id:
				combat_moment.emit("die", event)
				var delay := DEATH_HIDE_DELAY if body().has_method("has_animated_model") and body().has_animated_model() else 0.0
				if delay > 0.0:
					get_tree().create_timer(delay).timeout.connect(_hide_if_dead)
				else:
					body().visible = false
		"respawn":
			if event["id"] == entity_id:
				place_on_ground(spawn_position)
				body().visible = true
				combat_moment.emit("revive", event)
	_update_label()


func _hide_if_dead() -> void:
	if combatant and not combatant.is_alive():
		body().visible = false


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


## The local player's combatant, found once and shared by every entity.
static var _player_entity: WeakRef


func _player_combatant() -> RefCounted:
	var entity: Node = _player_entity.get_ref() if _player_entity else null
	if entity == null and is_inside_tree():
		var player := get_tree().get_first_node_in_group("player")
		entity = player.get_node_or_null("SimEntity") if player else null
		_player_entity = weakref(entity) if entity else null
	return entity.combatant if entity else null


func _update_label() -> void:
	if hp_label and combatant:
		var title := ""
		if not monster_id.is_empty():
			title = "%s (level %d)\n" % [display_name(), combatant.display_level]
			var me := _player_combatant()
			if me and me.skills:
				hp_label.modulate = LevelColors.color_for(combatant.display_level, me.skills.combat_level())
		hp_label.text = "%s%d / %d" % [title, combatant.hp, combatant.max_hp]
