extends "res://tests/test_case.gd"
## Rome's artisans: gold jewellery to Crafting 75 and cameo glass to 85,
## from materials the masters sell, and the masters buy the work.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1


func _make_sim(level: int) -> Simulation:
	var sim := Simulation.new(3)
	sim.add_player(PLAYER)
	sim.get_combatant(PLAYER).skills.xp["crafting"] = Skills.xp_for_level(level)
	sim.skilling.add_station("kiln", Vector3(1, 0, 0))
	return sim


func _craft(sim: Simulation, kind: String, recipe: String, count := 1) -> void:
	sim.queue_item_action(PLAYER, "craft", {"kind": kind, "recipe": recipe, "count": count})
	for i in 40:
		sim.step()


func test_cameo_glass_at_85() -> void:
	var sim := _make_sim(84)
	var player: RefCounted = sim.get_combatant(PLAYER)
	for item in [["blowpipe", 1], ["sand", 6], ["cobalt", 2]]:
		sim.give_item(PLAYER, item[0], item[1], "test", [])
	_craft(sim, "kiln", "cameo_glass_vase")
	check_eq(player.inventory.count("cameo_glass_vase"), 0, "not at 84")
	player.skills.xp["crafting"] = Skills.xp_for_level(85)
	_craft(sim, "kiln", "cameo_glass_vase")
	check_eq(player.inventory.count("cameo_glass_vase"), 1, "a cameo vase at 85")
	check_eq(player.inventory.count("cobalt"), 0, "the cobalt used")


func test_gold_jewellery_to_75() -> void:
	var sim := _make_sim(75)
	var player: RefCounted = sim.get_combatant(PLAYER)
	sim.give_item(PLAYER, "jewellers_tools", 1, "test", [])
	sim.give_item(PLAYER, "gold_bar", 4, "test", [])
	for i in 3:
		sim.give_item(PLAYER, "pearl", 1, "test", [])
	_craft(sim, "jewelcraft", "corona_aurea")
	check_eq(player.inventory.count("corona_aurea"), 1, "a corona aurea from three bars")
	_craft(sim, "jewelcraft", "pearl_necklace")
	check_eq(player.inventory.count("pearl_necklace"), 1, "a pearl necklace")


func test_masters_sell_materials_and_buy_the_work() -> void:
	var glass := ContentDB.shop("glassworks")
	check(glass["offers"].any(func(o): return o["item"] == "cobalt"), "Ennion sells cobalt")
	check(glass["buys"]["items"].has("cameo_glass_vase"), "and buys cameo glass")
	check(ContentDB.shop("goldsmith")["buys"]["items"].has("corona_aurea"), "Aurelia buys gold work")
	var levels := []
	for kind in ["jewelcraft", "kiln"]:
		for recipe in ContentDB.data()["skilling"]["recipes"][kind]:
			levels.append(recipe["level"])
	for band in [[60, 70], [70, 80], [80, 85]]:
		check(levels.any(func(l): return l >= band[0] and l <= band[1]), "a Crafting unlock between %d and %d" % band)
