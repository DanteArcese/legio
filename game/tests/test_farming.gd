extends "res://tests/test_case.gd"
## Farming: planting, growing, harvesting, and growth while away.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Farming := preload("res://scripts/sim/farming.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const HERBS := 1
const VEG := 2


func _make_sim(items := {"trowel": 1, "mint_seed": 3, "cabbage_seed": 3}) -> Simulation:
	var sim := Simulation.new(14)
	sim.add_player(PLAYER)
	sim.farming.add_patch(HERBS, "herb_patch", "HerbPatch1", Vector3(1, 0, 0))
	sim.farming.add_patch(VEG, "allotment", "Allotment1", Vector3(-1, 0, 0))
	for item_id in items:
		sim.give_item(PLAYER, item_id, items[item_id], "test", [])
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _run(sim: Simulation, ticks: int) -> Array:
	var events := []
	for i in ticks:
		events.append_array(sim.step())
	return events


func _farm(sim: Simulation, patch: int, seed := "") -> Array:
	sim.queue_item_action(PLAYER, "farm", {"patch": patch, "seed": seed})
	return _run(sim, 1)


func _grow_ticks(crop_id: String) -> int:
	var crop := ContentDB.crop(crop_id)
	return crop["stage_ticks"] * crop["stages"] + 2


func test_mint_grows_and_is_harvested() -> void:
	var sim := _make_sim()
	_farm(sim, HERBS, "mint_seed")
	var player := _player(sim)
	check_eq(player.inventory.count("mint_seed"), 2, "a seed planted")
	check_eq(player.skills.xp["farming"], 8.0, "planting xp")
	var events := _run(sim, _grow_ticks("mint"))
	check_eq(events.filter(func(e): return e["type"] == "patch_changed").size(), 4, "four stages of growth")
	check(Farming.is_ready(sim.farming.patches[HERBS]), "ready")
	_farm(sim, HERBS)
	var mint: int = player.inventory.count("mint")
	check(mint >= 3 and mint <= 5, "harvested 3 to 5 mint (%d)" % mint)
	check_eq(player.skills.xp["farming"], 8.0 + 10.0 * mint, "harvest xp per herb")
	check(sim.farming.patches[HERBS]["crop"].is_empty(), "the patch is clear again")


func test_seeds_only_grow_in_the_right_patch() -> void:
	var sim := _make_sim()
	var events := _farm(sim, VEG, "mint_seed")
	check(events.any(func(e): return e["type"] == "message" and "won't grow" in e["text"]), "mint isn't a vegetable")
	_farm(sim, VEG, "cabbage_seed")
	check_eq(sim.farming.patches[VEG]["crop"], "cabbage", "cabbage in the allotment")


func test_planting_needs_a_trowel_and_the_level() -> void:
	var sim := _make_sim({"sage_seed": 1, "mint_seed": 1})
	var events := _farm(sim, HERBS, "sage_seed")
	check(events.any(func(e): return e["type"] == "message" and "Farming 18" in e["text"]), "sage needs 18")
	events = _farm(sim, HERBS, "mint_seed")
	check(events.any(func(e): return e["type"] == "message" and "trowel" in e["text"]), "needs a trowel")


func test_checking_a_growing_patch_says_how_far_along() -> void:
	var sim := _make_sim()
	_farm(sim, HERBS, "mint_seed")
	var events := _farm(sim, HERBS)
	check(events.any(func(e): return e["type"] == "message" and "growing" in e["text"]), "still growing")


func test_crops_grow_while_the_game_is_closed() -> void:
	var sim := _make_sim()
	_farm(sim, HERBS, "mint_seed")
	var data := SaveGame.from_json(SaveGame.to_json(SaveGame.capture(sim, PLAYER, 1_000_000)))
	var loaded := _make_sim({})
	# Back after enough real time for the whole crop to grow.
	var away: int = 1_000_000 + int(ceil(_grow_ticks("mint") * Farming.TICK_SECONDS))
	check(SaveGame.restore(loaded, PLAYER, data, away), "restored")
	check(Farming.is_ready(loaded.farming.patches[HERBS]), "fully grown on return")


func test_a_short_absence_grows_a_little() -> void:
	var sim := _make_sim()
	_farm(sim, HERBS, "mint_seed")
	var data := SaveGame.from_json(SaveGame.to_json(SaveGame.capture(sim, PLAYER, 5000)))
	var loaded := _make_sim({})
	var one_stage: float = ContentDB.crop("mint")["stage_ticks"] * Farming.TICK_SECONDS
	SaveGame.restore(loaded, PLAYER, data, 5000 + int(one_stage) + 1)
	check_eq(loaded.farming.patches[HERBS]["stage"], 1, "one stage further on")
