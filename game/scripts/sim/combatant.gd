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
var bonuses := {"attack": 0, "strength": 0, "defence": 0, "ranged_attack": 0, "ranged_strength": 0}
## Players have skills and a combat style; monsters leave skills null.
var skills: Skills = null
var style := "accurate"
## Player-only containers; null for monsters.
var inventory: RefCounted = null
var equipment: RefCounted = null
var bank: RefCounted = null
## Slayer: current task ({} for none), points, and completed task count.
var slayer_task := {}
var slayer_points := 0
var slayer_tasks_done := 0
## Current skilling action ({} for none); see skilling.gd.
var skill_action := {}
## Who last hit this combatant, for kill credit.
var last_attacker_id := -1
## "standard" or "solitarius" (self-sufficient: no market or trading).
var account_mode := "standard"

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
	return skills.level(skill) if skills else levels.get(skill, 1)


func effective_level(skill: String) -> int:
	var style_bonus := 0
	if skills and Skills.STYLE_BONUS_SKILL[style] == skill:
		style_bonus = CombatMath.STYLE_BONUS
	return CombatMath.effective_level(level(skill), style_bonus)


func is_ranged() -> bool:
	return equipment != null and equipment.is_ranged()


func max_hit() -> int:
	if is_ranged():
		return CombatMath.max_hit(effective_level("ranged"), bonuses["ranged_strength"])
	return CombatMath.max_hit(effective_level("strength"), bonuses["strength"])


## Accuracy level and gear bonus used for attacks with the current weapon.
func attack_roll_parts() -> Array:
	if is_ranged():
		return [effective_level("ranged"), bonuses["ranged_attack"]]
	return [effective_level("attack"), bonuses["attack"]]


## How far away this combatant can attack from.
func attack_range() -> float:
	if not is_ranged():
		return reach
	return equipment.weapon()["range"] + (2.0 if style == "longrange" else 0.0)


func current_attack_speed() -> int:
	return attack_speed - 1 if style == "rapid" else attack_speed


## Recomputes bonuses and attack speed from worn equipment.
func apply_equipment() -> void:
	bonuses = equipment.bonuses()
	attack_speed = equipment.attack_speed()
	# Keep the combat style valid for the weapon type.
	var styles: Array = Skills.RANGED_STYLES if is_ranged() else Skills.MELEE_STYLES
	if not styles.has(style):
		style = styles[0]


func combat_level() -> int:
	return skills.combat_level() if skills else display_level
