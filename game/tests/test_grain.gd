extends "res://tests/test_case.gd"
## Grain: wheat sown in a grain field, ground into flour at a quern, and
## baked into bread.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Farming := preload("res://scripts/sim/farming.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const FIELD := 1


func _make_sim() -> Simulation:
	var sim := Simulation.new(21)
	sim.add_player(PLAYER)
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.skills.xp["farming"] = player.skills.xp_for_level(10)
	player.skills.xp["cooking"] = player.skills.xp_for_level(10)
	sim.farming.add_patch(FIELD, "grain_field", "GrainField1", Vector3(1, 0, 0))
	sim.skilling.add_station("quern", Vector3(0, 0, 1))
	sim.skilling.add_station("range", Vector3(-1, 0, 0))
	sim.give_item(PLAYER, "trowel", 1, "test", [])
	sim.give_item(PLAYER, "wheat_seed", 5, "test", [])
	return sim


func _run(sim: Simulation, ticks: int) -> void:
	for i in ticks:
		sim.step()


func test_wheat_grows_in_a_grain_field_only() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	sim.farming.add_patch(2, "herb_patch", "HerbPatch1", Vector3(-1, 0, 0))
	sim.queue_item_action(PLAYER, "farm", {"patch": 2, "seed": "wheat_seed"})
	_run(sim, 1)
	check(sim.farming.patches[2]["crop"].is_empty(), "wheat won't go in a herb patch")
	sim.queue_item_action(PLAYER, "farm", {"patch": FIELD, "seed": "wheat_seed"})
	_run(sim, 1)
	check_eq(sim.farming.patches[FIELD]["crop"], "wheat", "sown")
	var crop := ContentDB.crop("wheat")
	_run(sim, crop["stage_ticks"] * crop["stages"] + 2)
	check(Farming.is_ready(sim.farming.patches[FIELD]), "ripe")
	sim.queue_item_action(PLAYER, "farm", {"patch": FIELD, "seed": ""})
	_run(sim, 1)
	var wheat: int = player.inventory.count("wheat")
	check(wheat >= 5 and wheat <= 9, "harvested 5 to 9 sheaves (%d)" % wheat)


func test_wheat_to_flour_to_bread() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	sim.give_item(PLAYER, "wheat", 3, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "mill", "recipe": "flour", "count": 3})
	_run(sim, 14)
	check_eq(player.inventory.count("flour"), 3, "ground three pots of flour")
	sim.queue_item_action(PLAYER, "craft", {"kind": "cook", "recipe": "bread", "count": 3})
	_run(sim, 14)
	check_eq(player.inventory.count("bread") + player.inventory.count("burnt_food"), 3, "baked three loaves")
