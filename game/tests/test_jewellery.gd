extends "res://tests/test_case.gd"
## Jewellery: silver and gold bars worked by hand with jeweller's tools.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const Skilling := preload("res://scripts/sim/skilling.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1


func _make_sim(level: int, items: Dictionary) -> Simulation:
	var sim := Simulation.new(23)
	var player := sim.add_player(PLAYER)
	player.skills.xp["crafting"] = Skills.xp_for_level(level)
	for item_id in items:
		sim.give_item(PLAYER, item_id, items[item_id], "test", [])
	return sim


func _work(sim: Simulation, recipe: String) -> int:
	sim.queue_item_action(PLAYER, "craft", {"kind": "jewelcraft", "recipe": recipe, "count": 1})
	for i in 8:
		sim.step()
	return sim.get_combatant(PLAYER).inventory.count(recipe)


func test_jewellery_needs_the_tools() -> void:
	check_eq(_work(_make_sim(30, {"silver_bar": 1}), "silver_pendant"), 0, "no tools, no pendant")
	check_eq(_work(_make_sim(30, {"silver_bar": 1, "jewellers_tools": 1}), "silver_pendant"), 1, "a pendant")


func test_each_piece_has_its_level() -> void:
	check_eq(_work(_make_sim(44, {"gold_bar": 1, "jewellers_tools": 1}), "gold_bulla"), 0, "bulla needs 45")
	check_eq(_work(_make_sim(45, {"gold_bar": 1, "jewellers_tools": 1}), "gold_bulla"), 1, "at 45")


func test_jewellery_is_worked_anywhere() -> void:
	check(Skilling.HANDHELD_KINDS.has("jewelcraft"), "from the inventory")
	check(ContentDB.item("amulet_of_diana")["equip"]["bonuses"]["ranged_attack"] > 0, "Diana's amulet is for archers")
	check(ContentDB.item("silver_pendant")["equip"]["bonuses"]["ritus_attack"] > 0, "the pendant is for curse-writers")
