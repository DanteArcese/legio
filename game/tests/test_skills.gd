extends "res://tests/test_case.gd"

const Skills := preload("res://scripts/sim/skills.gd")


func test_curve_endpoints() -> void:
	check_eq(Skills.xp_for_level(1), 0.0, "level 1")
	check(Skills.xp_for_level(2) > 100.0 and Skills.xp_for_level(2) < 200.0, "level 2 = %s" % Skills.xp_for_level(2))
	var top := Skills.xp_for_level(99)
	check(top > 9_000_000.0 and top < 12_000_000.0, "level 99 = %s" % top)


func test_each_level_costs_more_than_the_last() -> void:
	var previous_gap := 0.0
	for level in range(2, 100):
		var gap := Skills.xp_for_level(level) - Skills.xp_for_level(level - 1)
		check(gap > previous_gap, "gap to %d (%s) should exceed %s" % [level, gap, previous_gap])
		previous_gap = gap


func test_level_for_xp_round_trips() -> void:
	for level in [1, 2, 10, 50, 98, 99]:
		check_eq(Skills.level_for_xp(Skills.xp_for_level(level)), level, "exactly level %d" % level)
		if level > 1:
			check_eq(Skills.level_for_xp(Skills.xp_for_level(level) - 1.0), level - 1, "just below %d" % level)
	check_eq(Skills.level_for_xp(Skills.MAX_XP), 99, "max xp")


func test_new_character_starts_at_level_1_with_10_vitality() -> void:
	var skills := Skills.new()
	check_eq(skills.level("attack"), 1, "attack")
	check_eq(skills.level("vitality"), 10, "vitality")
	check_eq(skills.combat_level(), 2, "combat level")


func test_add_xp_reports_level_ups() -> void:
	var skills := Skills.new()
	check_eq(skills.add_xp("mining", 10.0), 0, "no level")
	check_eq(skills.add_xp("mining", Skills.xp_for_level(5)), 5, "jump to 5")
	check_eq(skills.level("mining"), 5, "mining level")


func test_xp_is_capped() -> void:
	var skills := Skills.new()
	skills.add_xp("cooking", Skills.MAX_XP * 2)
	check_eq(skills.xp["cooking"], Skills.MAX_XP, "capped")


func test_maxed_combat_level_is_99() -> void:
	var skills := Skills.new()
	for skill in ["attack", "strength", "defence", "vitality"]:
		skills.xp[skill] = Skills.xp_for_level(99)
	check_eq(skills.combat_level(), 99, "maxed")
