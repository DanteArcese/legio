extends "res://tests/test_case.gd"

const CombatMath := preload("res://scripts/sim/combat_math.gd")


func test_effective_level_adds_offset_and_style() -> void:
	check_eq(CombatMath.effective_level(1, 0), 9, "level 1, no style")
	check_eq(CombatMath.effective_level(50, 3), 61, "level 50 with style")


func test_even_match_favours_attacker_slightly() -> void:
	var chance := CombatMath.hit_chance(20, 0, 20, 0)
	check(chance > 0.5 and chance < 0.6, "even chance %s" % chance)


func test_higher_attack_and_gear_raise_hit_chance() -> void:
	var base := CombatMath.hit_chance(20, 0, 20, 0)
	check(CombatMath.hit_chance(40, 0, 20, 0) > base, "higher attack")
	check(CombatMath.hit_chance(20, 20, 20, 0) > base, "attack gear")
	check(CombatMath.hit_chance(20, 0, 20, 20) < base, "defence gear")


func test_negative_bonuses_never_break_the_formula() -> void:
	var chance := CombatMath.hit_chance(9, -500, 9, -500)
	check(chance > 0.0 and chance < 1.0, "chance %s" % chance)


func test_max_hit_scales_with_strength_and_gear() -> void:
	check_eq(CombatMath.max_hit(9, 0), 1, "fresh character")
	check(CombatMath.max_hit(110, 0) > CombatMath.max_hit(50, 0), "strength level")
	check(CombatMath.max_hit(50, 12) > CombatMath.max_hit(50, 0), "strength gear")
	var maxed := CombatMath.max_hit(110, 80)
	check(maxed >= 35 and maxed <= 50, "maxed with endgame gear %d" % maxed)
