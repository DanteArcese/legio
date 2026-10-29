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
var bonuses := {"attack": 0, "strength": 0, "defence": 0, "ranged_attack": 0, "ranged_strength": 0,
	"ritus_attack": 0, "ritus_strength": 0, "ranged_defence": 0, "ritus_defence": 0}
## Curses on this combatant: "bound" -> until tick; "withering" ->
## {"until", "next", "damage", "source"}.
var curses := {}
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
## Monsters this player has paid never to be assigned, and Slayer unlocks bought.
var slayer_blocked: Array = []
var slayer_unlocks: Array = []
## Arena: the current capture contract ({"id", "remaining"} or {}), and
## how many have been handed in.
var arena_contract := {}
var arena_contracts_done := 0
## Impetus (0-100) for weapon specials, and whether the next attack spends it.
const MAX_IMPETUS := 100
var impetus := MAX_IMPETUS
var special_armed := false
## Held by a siren's song until this tick (see combat.gd).
var entranced_until := 0
## Pietas: favour points, active blessing ids, and their summed boosts
## (e.g. {"strength": 0.05}); see pietas.gd.
var favour := 1.0
var blessings: Array = []
var blessing_boosts := {}
## Medicina remedies: skill -> {"amount": levels, "next_decay": tick}. Each
## boost wears off a level at a time.
var remedy_boosts := {}
## Ritual pollution from casting curses (0-100); see pietas.gd.
var pollution := 0.0
## Summoned allies (shades of the Manes): who called them, and when they fade.
var summoned_by := -1
var expires_at := -1
## Tick of the last warning from the town watch (-1 for never).
var watch_warned_at := -1
var watch_fined_at := -1
## Current skilling action ({} for none); see skilling.gd.
var skill_action := {}
## Athletics: the obstacle being crossed ({} for none: {"id", "until", "falls"}),
## the next obstacle in order for a lap, and laps run.
var obstacle := {}
## A chariot race under way: {"start", "lap", "sector", "finishes"}, or {}.
var race := {}
## The munera under way: {"wave", "alive", "spawned", "rest_until", "earned"}, or {}.
var games := {}
## The most munera waves cleared in one go.
var games_best := 0
## Saved sets of gear: each {} or {"worn": {slot: item}, "style": style}.
const LOADOUT_COUNT := 4
var loadouts: Array = [{}, {}, {}, {}]
var course_next := 0
var laps := 0
## Stunned (by a failed pickpocket) until this tick: no attacks, thefts, or walking.
var stunned_until := -1
## The next tick the player may try another theft.
var thieving_ready_at := -1
## Who last hit this combatant, for kill credit.
var last_attacker_id := -1
## The villa: owned or not, and hotspot id -> furniture id.
var villa_owned := false
## Rested on the villa's mosaic: a small XP bonus until this tick.
var rested_until := -1
var villa_furniture := {}
## Real time (seconds) the villa's steward last settled the books.
var steward_since := 0.0
## Mercatura: the current trade contract ({} or {"id"}) and how many are done.
var trade_contract := {}
var contracts_done := 0
## The collection log (the Tabularium): item id -> how many obtained.
var collection := {}
## The pet following this player, or "".
var pet := ""
## Quest progress: quest id -> {"step", "progress", "done"}; see quests.gd.
var quests := {}
## A label quests can point at, for things that aren't monsters (the training dummy).
var tag := ""
## "standard", "solitarius" (self-sufficient: no market or trading), or
## "hardcore" (a Solitarius with one life; a death makes it a plain Solitarius).
var account_mode := "standard"
## Region tasks done, as "region/task" keys (see tasks.gd).
var tasks_done: Array = []
## Seared by fire until this tick: no regeneration (the hydra's) till then.
var seared_until := 0

## Content id for monsters ("" for players and props). Used for drops.
var monster_id := ""
var drop_table := ""
## Shown level, used to decide aggression.
var display_level := 1
## How much a draining curse saps Attack and Defence (matches curses.gd).
const DRAIN_SHARE := 0.1
## How a monster attacks: "melee", "ranged" or "ritus" (players use their weapon).
var attack_kind := "melee"

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


## Levels added by a remedy right now (0 for none).
func remedy_boost(skill: String) -> int:
	return remedy_boosts.get(skill, {}).get("amount", 0)


func effective_level(skill: String) -> int:
	var style_bonus := 0
	if skills and Skills.STYLE_BONUS_SKILL[style] == skill:
		style_bonus = CombatMath.STYLE_BONUS
	# Blessings raise the level itself, e.g. +5% Strength.
	var boosted := floori(level(skill) * (1.0 + blessing_boosts.get(skill, 0.0))) + remedy_boost(skill)
	# A draining curse saps the arm and the guard.
	if curses.has("drained") and skill in ["attack", "defence"]:
		boosted = floori(boosted * (1.0 - DRAIN_SHARE))
	return CombatMath.effective_level(boosted, style_bonus)


## "melee", "ranged", or "ritus": how this combatant's weapon works (range,
## ammunition, which levels it uses). Monsters fight in melee.
func combat_kind() -> String:
	return equipment.combat_kind() if equipment else "melee"


## The kind of blow this combatant lands, which the target defends against
## and can be protected from: a player's weapon kind, or a monster's
## attack_kind (a lemur's touch is a curse, though it fights up close).
func attack_type() -> String:
	return equipment.combat_kind() if equipment else attack_kind


func is_ranged() -> bool:
	return combat_kind() == "ranged"


## Solitarius rules apply to hardcore characters too.
func is_solitarius() -> bool:
	return account_mode == "solitarius" or account_mode == "hardcore"


func uses_ammo() -> bool:
	return combat_kind() != "melee"


func max_hit() -> int:
	match combat_kind():
		"ranged":
			return CombatMath.max_hit(effective_level("ranged"), bonuses["ranged_strength"])
		"ritus":
			return CombatMath.max_hit(effective_level("ritus"), bonuses["ritus_strength"])
	return CombatMath.max_hit(effective_level("strength"), bonuses["strength"])


## Accuracy level and gear bonus used for attacks with the current weapon.
func attack_roll_parts() -> Array:
	match combat_kind():
		"ranged":
			return [effective_level("ranged"), bonuses["ranged_attack"]]
		"ritus":
			return [effective_level("ritus"), bonuses["ritus_attack"]]
	return [effective_level("attack"), bonuses["attack"]]


## Defence gear bonus against an attack of this kind: the base Defence bonus
## plus any kind-specific modifier (metal armour is weak to curses, robes
## are weak to arrows).
func defence_bonus_against(kind: String) -> int:
	match kind:
		"ranged":
			return bonuses["defence"] + bonuses["ranged_defence"]
		"ritus":
			return bonuses["defence"] + bonuses["ritus_defence"]
	return bonuses["defence"]


func is_bound(tick: int) -> bool:
	return curses.get("bound", -1) > tick


## How far away this combatant can attack from.
func attack_range() -> float:
	if not uses_ammo():
		return reach
	return equipment.weapon()["range"] + (2.0 if style == "longrange" else 0.0)


## Ticks between attacks right now: Rapid is a tick faster, and a Binding
## curse makes the victim a tick slower.
func current_attack_speed(tick := -1) -> int:
	var speed := attack_speed - 1 if style == "rapid" else attack_speed
	return speed + 1 if is_bound(tick) else speed


## Recomputes bonuses and attack speed from worn equipment.
func apply_equipment() -> void:
	bonuses = equipment.bonuses()
	attack_speed = equipment.attack_speed()
	# Keep the combat style valid for the weapon type.
	var styles: Array = Skills.styles_for(combat_kind())
	if not styles.has(style):
		style = styles[0]


func combat_level() -> int:
	return skills.combat_level() if skills else display_level
