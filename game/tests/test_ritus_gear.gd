extends "res://tests/test_case.gd"
## Ritus gear: the silver and orichalcum lituus and the augur's robes.

const Simulation := preload("res://scripts/sim/simulation.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1


func _make_sim() -> Simulation:
	var sim := Simulation.new(13)
	var player := sim.add_player(PLAYER)
	for skill in ["crafting", "smithing"]:
		player.skills.xp[skill] = player.skills.xp_for_level(60)
	sim.skilling.add_station("anvil", Vector3(1, 0, 0))
	return sim


func _craft(sim: Simulation, kind: String, recipe: String) -> void:
	sim.queue_item_action(PLAYER, "craft", {"kind": kind, "recipe": recipe, "count": 1})
	for i in 8:
		sim.step()


func test_foci_climb_in_tiers() -> void:
	var foci := ["lituus", "silver_lituus", "orichalcum_lituus"].map(func(id): return ContentDB.item(id)["equip"]["bonuses"]["ritus_attack"])
	check(foci[0] < foci[1] and foci[1] < foci[2], "each lituus beats the last (%s)" % [foci])
	check(ContentDB.item("augurs_robe")["equip"]["bonuses"]["ritus_attack"] > ContentDB.item("ritual_robe")["equip"]["bonuses"]["ritus_attack"], "the augur's robe beats the ritual robe")


func test_the_new_gear_is_made() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	for item in {"jewellers_tools": 1, "silver_bar": 4, "oak_logs": 2, "hammer": 1, "orichalcum_bar": 2, "needle": 1, "linen": 8, "thread": 5}.keys():
		var quantity: int = {"jewellers_tools": 1, "silver_bar": 4, "oak_logs": 2, "hammer": 1, "orichalcum_bar": 2, "needle": 1, "linen": 8, "thread": 5}[item]
		sim.give_item(PLAYER, item, quantity, "test", [])
	_craft(sim, "jewelcraft", "silver_lituus")
	_craft(sim, "smith", "orichalcum_lituus")
	_craft(sim, "leatherwork", "augurs_robe")
	_craft(sim, "leatherwork", "augurs_hood")
	for item in ["silver_lituus", "orichalcum_lituus", "augurs_robe", "augurs_hood"]:
		check_eq(player.inventory.count(item), 1, "made %s" % item)
