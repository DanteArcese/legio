extends "res://tests/test_case.gd"
## Examining gear shows its stats, requirements, and what's worn there.

const GameUi := preload("res://scripts/ui/game_ui.gd")


func test_gear_examine_lists_bonuses_and_requirements() -> void:
	var text := GameUi.examine_text("steel_gladius", {"weapon": "bronze_pugio"})
	check("Attack +20" in text and "Strength +18" in text, "bonuses (%s)" % text)
	check("speed 4" in text, "attack speed")
	check("needs Attack 20" in text, "requirement")
	check("(Wearing: Bronze pugio)" in text, "what's in the slot now")


func test_ranged_gear_shows_reach_and_plain_items_stay_plain() -> void:
	var bow := GameUi.examine_text("composite_bow", {})
	check("Ranged +18" in bow and "reach 8 m" in bow, "a bow's reach (%s)" % bow)
	check(not "Wearing" in bow, "nothing worn, nothing said")
	check_eq(GameUi.examine_text("bread", {}), "A round loaf of panis quadratus.", "bread is just bread")
