extends "res://tests/test_case.gd"
## Farming past 40: figs and cedars in the orchard plots, the Falernian and
## Caecuban vines on the trellises, and their wines from the press.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Farming := preload("res://scripts/sim/farming.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const ORCHARD := 5
const TRELLIS := 6


func _make_sim(farming: int) -> Simulation:
	var sim := Simulation.new(4)
	sim.add_player(PLAYER)
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.skills.xp["farming"] = player.skills.xp_for_level(farming)
	player.skills.xp["cooking"] = player.skills.xp_for_level(80)
	sim.farming.add_patch(ORCHARD, "olive_grove", "Orchard1", Vector3(1, 0, 0))
	sim.farming.add_patch(TRELLIS, "vine_trellis", "Trellis1", Vector3(-1, 0, 0))
	sim.skilling.add_station("wine_press", Vector3(0, 0, 1))
	sim.give_item(PLAYER, "trowel", 1, "test", [])
	return sim


func _grow(sim: Simulation, patch: int, crop_id: String) -> void:
	var crop := ContentDB.crop(crop_id)
	for i in crop["stage_ticks"] * crop["stages"] + 2:
		sim.step()
	check(Farming.is_ready(sim.farming.patches[patch]), "%s ripe" % crop_id)


func test_figs_in_the_orchard() -> void:
	var sim := _make_sim(45)
	var player: RefCounted = sim.get_combatant(PLAYER)
	sim.give_item(PLAYER, "fig_sapling", 1, "test", [])
	sim.queue_item_action(PLAYER, "farm", {"patch": ORCHARD, "seed": "fig_sapling"})
	sim.step()
	check_eq(sim.farming.patches[ORCHARD]["crop"], "fig", "a fig planted")
	_grow(sim, ORCHARD, "fig")
	sim.queue_item_action(PLAYER, "farm", {"patch": ORCHARD, "seed": ""})
	sim.step()
	check(player.inventory.count("figs") >= 10, "a fig harvest (%d)" % player.inventory.count("figs"))


func test_cedar_needs_70() -> void:
	var sim := _make_sim(69)
	sim.give_item(PLAYER, "cedar_sapling", 1, "test", [])
	sim.queue_item_action(PLAYER, "farm", {"patch": ORCHARD, "seed": "cedar_sapling"})
	sim.step()
	check(sim.farming.patches[ORCHARD]["crop"].is_empty(), "not at 69")


func test_falernian_from_vine_to_amphora() -> void:
	var sim := _make_sim(60)
	var player: RefCounted = sim.get_combatant(PLAYER)
	sim.give_item(PLAYER, "falernian_cutting", 1, "test", [])
	sim.queue_item_action(PLAYER, "farm", {"patch": TRELLIS, "seed": "falernian_cutting"})
	sim.step()
	_grow(sim, TRELLIS, "falernian")
	sim.queue_item_action(PLAYER, "farm", {"patch": TRELLIS, "seed": ""})
	sim.step()
	check(player.inventory.count("falernian_grapes") >= 5, "Falernian grapes")
	sim.queue_item_action(PLAYER, "craft", {"kind": "press_wine", "recipe": "falernian_wine", "count": 1})
	for i in 20:
		sim.step()
	check_eq(player.inventory.count("falernian_wine"), 1, "an amphora of Falernian")
