extends RefCounted
## Combat state for one entity in the simulation. Plain data, no scene nodes.

var id: int
var max_hp := 10
var hp := 10
## Ticks between attacks (OSRS-style weapon speed).
var attack_speed := 4
var max_hit := 1
## Chance in 0..1 that an attack lands.
var accuracy := 0.75
## Distance within which this combatant can attack its target.
var reach := 1.5
var auto_retaliate := true
## Ticks until respawn after death; -1 means it stays dead.
var respawn_ticks := -1

var position := Vector3.ZERO
var target_id := -1
var next_attack_tick := 0
var respawn_at_tick := -1


func _init(p_id: int) -> void:
	id = p_id


func is_alive() -> bool:
	return hp > 0


func can_attack() -> bool:
	return max_hit > 0
