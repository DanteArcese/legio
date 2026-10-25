extends RefCounted
## State for one entity in the simulation: combat stats plus, for monsters,
## a simple AI brain. Plain data, no scene nodes.

const Skills := preload("res://scripts/sim/skills.gd")
const CombatMath := preload("res://scripts/sim/combat_math.gd")

var id: int
var max_hp := 10
var hp := 10
## Ticks between attacks (weapon speed).
var attack_speed := 4
## Distance within which this combatant can attack its target.
var reach := 1.5
## False for things that never attack, like the training dummy.
var can_fight := true
var auto_retaliate := true
## Ticks until respawn after death; -1 means it stays dead.
var respawn_ticks := -1

## Combat levels for monsters. Players use their skills instead.
var levels := {"attack": 1, "strength": 1, "defence": 1}
## Equipment bonuses.
var bonuses := {"attack": 0, "strength": 0, "defence": 0}
## Players have skills and a combat style; monsters leave skills null.
var skills: Skills = null
var style := "accurate"
## Content id for monsters ("" for players and props). Used for drops.
var monster_id := ""
var drop_table := ""
## Shown level, used to decide aggression.
var display_level := 1

## AI brain (monsters only).
var has_brain := false
var aggressive := false
var aggro_radius := 6.0
var leash_radius := 14.0
var wander_radius := 4.0
var spawn_position := Vector3.ZERO
var returning := false
## Where the scene should move this entity, or null to stand still.
var move_target: Variant = null

var position := Vector3.ZERO
var target_id := -1
var next_attack_tick := 0
var respawn_at_tick := -1


func _init(p_id: int) -> void:
	id = p_id


func is_alive() -> bool:
	return hp > 0


func is_player() -> bool:
	return skills != null


func level(skill: String) -> int:
	return skills.level(skill) if skills else levels[skill]


func effective_level(skill: String) -> int:
	var style_bonus := 0
	if skills and Skills.STYLE_SKILLS[style] == skill:
		style_bonus = CombatMath.STYLE_BONUS
	return CombatMath.effective_level(level(skill), style_bonus)


func max_hit() -> int:
	return CombatMath.max_hit(effective_level("strength"), bonuses["strength"])


func combat_level() -> int:
	return skills.combat_level() if skills else display_level
