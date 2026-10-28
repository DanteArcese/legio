extends "res://tests/test_case.gd"
## Monster level colours by the gap to the player's combat level.

const LevelColors := preload("res://scripts/ui/level_colors.gd")


func test_colours_climb_with_the_gap() -> void:
	check_eq(LevelColors.color_for(1, 30), LevelColors.FAR_BELOW, "far below")
	check_eq(LevelColors.color_for(25, 30), LevelColors.BELOW, "below")
	check_eq(LevelColors.color_for(30, 30), LevelColors.EVEN, "even")
	check_eq(LevelColors.color_for(32, 30), LevelColors.EVEN, "close enough")
	check_eq(LevelColors.color_for(35, 30), LevelColors.ABOVE, "above")
	check_eq(LevelColors.color_for(8, 2), LevelColors.ABOVE, "a boar for a new player")
	check_eq(LevelColors.color_for(75, 30), LevelColors.FAR_ABOVE, "far above")
