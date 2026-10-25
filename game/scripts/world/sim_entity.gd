extends Node
## Links a scene body (this node's parent) to a combatant in the simulation.
## Monsters take their stats from content via monster_id; other entities
## (the player, the training dummy) are configured with the exports below.

const HitSplat := preload("res://scripts/world/hit_splat.gd")
const Skills := preload("res://scripts/sim/skills.gd")
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
## Players get skills and earn XP; their max HP follows Vitality.
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
		if is_player:
			combatant.skills = Skills.new()
			combatant.max_hp = combatant.skills.level("vitality")
			combatant.hp = combatant.max_hp
	_update_label()


func display_name() -> String:
	return ContentDB.monster(monster_id)["name"] if not monster_id.is_empty() else body().name


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
				body().global_position = spawn_position
				body().visible = true
	_update_label()


func _update_label() -> void:
	if hp_label and combatant:
		var title := ""
		if not monster_id.is_empty():
			title = "%s (level %d)\n" % [display_name(), combatant.display_level]
		hp_label.text = "%s%d / %d" % [title, combatant.hp, combatant.max_hp]
