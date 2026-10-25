extends RefCounted
## A player's skill levels and experience.
##
## Our own XP curve: each level costs a little more than the last, with the
## cost roughly doubling every 7.3 levels. Level 2 needs 89 XP, level 10
## about 1.2k, and level 99 about 9.9M.
## The constants are first guesses, to be tuned by playtesting.

const NAMES := ["attack", "strength", "defence", "vitality", "ranged", "ritus", "slayer", "mining", "smithing", "cooking"]
const MAX_LEVEL := 99
const MAX_XP := 200_000_000.0
const CURVE_SCALE := 900.0
const CURVE_DOUBLING := 7.3
const VITALITY_START_LEVEL := 10

## Combat XP per point of damage.
const STYLE_XP_PER_DAMAGE := 4.0
const VITALITY_XP_PER_DAMAGE := 4.0 / 3.0

## Combat style -> the skills that share its XP.
const STYLE_SKILLS := {
	"accurate": ["attack"], "aggressive": ["strength"], "defensive": ["defence"],
	"aimed": ["ranged"], "rapid": ["ranged"], "longrange": ["ranged", "defence"],
	"focused": ["ritus"], "warding": ["ritus", "defence"],
}
## Combat style -> the skill its +3 effective-level bonus applies to.
const STYLE_BONUS_SKILL := {
	"accurate": "attack", "aggressive": "strength", "defensive": "defence",
	"aimed": "ranged", "rapid": "", "longrange": "defence",
	"focused": "ritus", "warding": "defence",
}
const MELEE_STYLES := ["accurate", "aggressive", "defensive"]
const RANGED_STYLES := ["aimed", "rapid", "longrange"]
const RITUS_STYLES := ["focused", "warding"]
const STYLES := MELEE_STYLES + RANGED_STYLES + RITUS_STYLES


## The combat styles available with a weapon of this kind (melee, ranged, ritus).
static func styles_for(kind: String) -> Array:
	match kind:
		"ranged":
			return RANGED_STYLES
		"ritus":
			return RITUS_STYLES
	return MELEE_STYLES

static var _thresholds: PackedFloat64Array = _build_thresholds()

var xp := {}


func _init() -> void:
	for skill in NAMES:
		xp[skill] = 0.0
	xp["vitality"] = xp_for_level(VITALITY_START_LEVEL)


## Total XP needed to reach a level.
static func xp_for_level(level: int) -> float:
	if level <= 1:
		return 0.0
	var steps := float(level - 1)
	return floorf(CURVE_SCALE * (pow(2.0, steps / CURVE_DOUBLING) - 1.0))


static func level_for_xp(amount: float) -> int:
	var level := 1
	while level < MAX_LEVEL and amount >= _thresholds[level + 1]:
		level += 1
	return level


static func _build_thresholds() -> PackedFloat64Array:
	var thresholds := PackedFloat64Array()
	thresholds.resize(MAX_LEVEL + 1)
	for level in range(1, MAX_LEVEL + 1):
		thresholds[level] = xp_for_level(level)
	return thresholds


func level(skill: String) -> int:
	return level_for_xp(xp[skill])


## Adds XP and returns the new level if it went up, otherwise 0.
func add_xp(skill: String, amount: float) -> int:
	var before := level(skill)
	xp[skill] = minf(xp[skill] + amount, MAX_XP)
	var after := level(skill)
	return after if after > before else 0


## Our own combat level formula: offence (Attack + Strength, or twice
## Ranged or Ritus if higher) plus Defence and half of Vitality, over 3.5.
## It runs from 2 for a new character to 99 when maxed.
func combat_level() -> int:
	var offence := maxi(level("attack") + level("strength"), maxi(level("ranged"), level("ritus")) * 2)
	return floori((offence + level("defence") + level("vitality") * 0.5) / 3.5)
