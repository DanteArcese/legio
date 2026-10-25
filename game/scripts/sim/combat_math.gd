extends RefCounted
## Our own combat formulas. Pure functions, tuned by playtesting.
##
## Effective level = level + style bonus + 8.
## Hit chance compares attack and defence ratings, each scaled by gear:
##   chance = A / (A + DEFENCE_WEIGHT * D)
## Max hit grows with effective Strength and the gear strength bonus.

const LEVEL_OFFSET := 8
const STYLE_BONUS := 3
## Below 1, so an evenly matched attacker lands a bit more than half its hits.
const DEFENCE_WEIGHT := 0.8
const ACCURACY_GEAR_SCALE := 50.0
const STRENGTH_GEAR_SCALE := 40.0
const MAX_HIT_DIVISOR := 8.0


static func effective_level(level: int, style_bonus: int) -> int:
	return level + style_bonus + LEVEL_OFFSET


static func hit_chance(attack_effective: int, attack_bonus: int, defence_effective: int, defence_bonus: int) -> float:
	var attack := attack_effective * _gear_scale(attack_bonus, ACCURACY_GEAR_SCALE)
	var defence := defence_effective * _gear_scale(defence_bonus, ACCURACY_GEAR_SCALE) * DEFENCE_WEIGHT
	return attack / (attack + defence)


static func max_hit(strength_effective: int, strength_bonus: int) -> int:
	return maxi(1, floori(0.5 + strength_effective * _gear_scale(strength_bonus, STRENGTH_GEAR_SCALE) / MAX_HIT_DIVISOR))


static func _gear_scale(bonus: int, scale: float) -> float:
	return maxf(1.0 + bonus / scale, 0.1)
