extends Node
## Links a scene body (this node's parent) to a combatant in the simulation.
## Stats are configured here for now; they move to content data files later.

const HitSplat := preload("res://scripts/world/hit_splat.gd")

@export var entity_id := 0
@export var max_hp := 10
@export var attack_speed := 4
@export var max_hit := 1
@export_range(0.0, 1.0) var accuracy := 0.75
@export var reach := 1.5
@export var auto_retaliate := true
@export var respawn_ticks := -1
## Whether the player can target this entity.
@export var attackable := true
@export var hp_label: Label3D

var combatant: RefCounted


func body() -> Node3D:
	return get_parent()


func configure(p_combatant: RefCounted) -> void:
	combatant = p_combatant
	combatant.max_hp = max_hp
	combatant.hp = max_hp
	combatant.attack_speed = attack_speed
	combatant.max_hit = max_hit
	combatant.accuracy = accuracy
	combatant.reach = reach
	combatant.auto_retaliate = auto_retaliate
	combatant.respawn_ticks = respawn_ticks
	_update_label()


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
				body().visible = true
	_update_label()


func _update_label() -> void:
	if hp_label and combatant:
		hp_label.text = "%d / %d" % [combatant.hp, combatant.max_hp]
