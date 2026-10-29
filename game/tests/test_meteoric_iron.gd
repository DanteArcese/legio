extends "res://tests/test_case.gd"
## Meteoric iron, the top metal tier: mined at 70 in the frontier's crater,
## smelted at 70, smithed from 72 to 88, and its tools are tier 5.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const Skilling := preload("res://scripts/sim/skilling.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1


func test_the_tier_above_orichalcum() -> void:
	for kind in ["gladius", "lorica", "scutum", "galea"]:
		var meteoric: Dictionary = ContentDB.item("meteoric_" + kind)["equip"]["bonuses"]
		var orichalcum: Dictionary = ContentDB.item("orichalcum_" + kind)["equip"]["bonuses"]
		var key := "attack" if kind == "gladius" else "defence"
		check(meteoric[key] > orichalcum[key], "the meteoric %s beats orichalcum" % kind)
	check_eq(ContentDB.item("meteoric_pickaxe")["tool_tier"], 5, "tier-5 tools")
	check(Skilling.MINE_TICKS.has(5) and Skilling.CHOP_TICKS.has(5), "tier 5 swings")
	check(Skilling.mine_chance(80, ContentDB.rock("meteoric_rock"), 5) > Skilling.mine_chance(80, ContentDB.rock("meteoric_rock"), 4), "and lands more often")


func test_mine_smelt_and_smith() -> void:
	var sim := Simulation.new(3)
	var player := sim.add_player(PLAYER)
	for skill in ["mining", "smithing"]:
		player.skills.xp[skill] = Skills.xp_for_level(90)
	player.inventory.slots.fill(null)
	sim.give_item(PLAYER, "meteoric_pickaxe", 1, "test", [])
	sim.give_item(PLAYER, "hammer", 1, "test", [])
	sim.skilling.add_rock(40, "meteoric_rock", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "mine", {"rock": 40})
	for i in 200:
		sim.step()
		if player.inventory.count("meteoric_ore") > 0:
			break
	check(player.inventory.count("meteoric_ore") > 0, "star-iron mined")
	sim.skilling.add_station("furnace", Vector3(0, 0, 1))
	sim.skilling.add_station("anvil", Vector3(-1, 0, 0))
	sim.give_item(PLAYER, "meteoric_ore", 2, "test", [])
	sim.give_item(PLAYER, "coal", 18, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "smelt", "recipe": "meteoric_bar", "count": 2})
	for i in 30:
		sim.step()
	check(player.inventory.count("meteoric_bar") >= 2, "smelted")
	sim.queue_item_action(PLAYER, "craft", {"kind": "smith", "recipe": "meteoric_gladius", "count": 1})
	for i in 30:
		sim.step()
	check_eq(player.inventory.count("meteoric_gladius"), 1, "a meteoric gladius")
