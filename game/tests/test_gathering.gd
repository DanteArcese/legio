extends "res://tests/test_case.gd"
## Woodcutting, Fishing, Fletching, and cooking at a campfire.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skilling := preload("res://scripts/sim/skilling.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const TREE := 1
const SPOT := 1


func _make_sim(items := {}) -> Simulation:
	var sim := Simulation.new(5)
	sim.add_player(PLAYER)
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


func _set_level(sim: Simulation, skill: String, level: int) -> void:
	_player(sim).skills.xp[skill] = _player(sim).skills.xp_for_level(level)


func test_a_common_tree_falls_after_one_log_and_regrows() -> void:
	var sim := _make_sim({"bronze_axe": 1})
	sim.skilling.add_tree(TREE, "tree", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "chop", {"tree": TREE})
	var events := _run(sim, 80)
	check_eq(_player(sim).inventory.count("logs"), 1, "one log from a common tree")
	check_eq(_player(sim).skills.xp["woodcutting"], 22.0, "woodcutting xp")
	check(events.any(func(e): return e["type"] == "tree_felled"), "felled")
	check(events.any(func(e): return e["type"] == "tree_regrown"), "regrows")


func test_oaks_give_several_logs_before_falling() -> void:
	var sim := _make_sim({"iron_axe": 1})
	_set_level(sim, "woodcutting", 40)
	sim.skilling.add_tree(TREE, "oak_tree", Vector3(1, 0, 0))
	var most := 0
	for attempt in 6:
		sim.queue_item_action(PLAYER, "chop", {"tree": TREE})
		var before: int = _player(sim).inventory.count("oak_logs")
		var events := _run(sim, 200)
		var felled := events.filter(func(e): return e["type"] == "tree_felled").size()
		if felled > 0:
			most = maxi(most, _player(sim).inventory.count("oak_logs") - before)
	check(most > 1, "an oak gave several logs at once (best run: %d)" % most)


func test_chopping_needs_level_and_axe() -> void:
	var sim := _make_sim()
	sim.skilling.add_tree(TREE, "oak_tree", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "chop", {"tree": TREE})
	var events := _run(sim, 2)
	check(events.any(func(e): return e["type"] == "message" and "Woodcutting 15" in e["text"]), "level gate")
	sim.skilling.add_tree(2, "tree", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "chop", {"tree": 2})
	events = _run(sim, 2)
	check(events.any(func(e): return e["type"] == "message" and "axe" in e["text"]), "needs an axe")


func test_iron_axe_needs_woodcutting_10() -> void:
	var sim := _make_sim({"iron_axe": 1})
	check_eq(Skilling.tool_tier(_player(sim), "axe"), 0, "too low to use it")
	_set_level(sim, "woodcutting", 10)
	check_eq(Skilling.tool_tier(_player(sim), "axe"), 2, "usable at 10")


func test_net_fishing_catches_sardines_until_full() -> void:
	var sim := _make_sim({"small_net": 1})
	sim.skilling.add_fishing_spot(SPOT, "net_spot", Vector3(2.5, 0, 0))
	sim.queue_item_action(PLAYER, "fish", {"spot": SPOT})
	_run(sim, 2000)
	var player := _player(sim)
	check_eq(player.inventory.count("raw_sardine"), 27, "fills every free slot")
	check_eq(player.inventory.count("raw_anchovy"), 0, "anchovies need Fishing 10")
	check(player.skill_action.is_empty(), "stops when full")


func test_higher_levels_land_better_fish() -> void:
	var sim := _make_sim({"small_net": 1})
	_set_level(sim, "fishing", 30)
	sim.skilling.add_fishing_spot(SPOT, "net_spot", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "fish", {"spot": SPOT})
	_run(sim, 300)
	check(_player(sim).inventory.count("raw_anchovy") > 0, "anchovies at 30")


func test_rod_spot_needs_a_rod_and_level() -> void:
	var sim := _make_sim({"small_net": 1})
	sim.skilling.add_fishing_spot(SPOT, "rod_spot", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "fish", {"spot": SPOT})
	var events := _run(sim, 2)
	check(events.any(func(e): return e["type"] == "message" and "Fishing 20" in e["text"]), "level gate")
	_set_level(sim, "fishing", 20)
	sim.queue_item_action(PLAYER, "fish", {"spot": SPOT})
	events = _run(sim, 2)
	check(events.any(func(e): return e["type"] == "message" and "fishing rod" in e["text"]), "needs a rod")


func test_fishing_stops_when_walking_away() -> void:
	var sim := _make_sim({"small_net": 1})
	sim.skilling.add_fishing_spot(SPOT, "net_spot", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "fish", {"spot": SPOT})
	_run(sim, 2)
	sim.set_position(PLAYER, Vector3(10, 0, 0))
	_run(sim, 6)
	check(_player(sim).skill_action.is_empty(), "stopped")


func test_fletching_needs_no_station() -> void:
	var sim := _make_sim({"knife": 1, "logs": 3})
	sim.queue_item_action(PLAYER, "craft", {"kind": "fletch", "recipe": "arrow_shaft", "count": 3})
	_run(sim, 20)
	check_eq(_player(sim).inventory.count("arrow_shaft"), 45, "15 shafts per log")
	check_eq(_player(sim).skills.xp["fletching"], 18.0, "fletching xp")


func test_arrows_from_shafts_feathers_and_heads() -> void:
	var sim := _make_sim({"arrow_shaft": 30, "feather": 30, "bronze_arrowheads": 30})
	sim.queue_item_action(PLAYER, "craft", {"kind": "fletch", "recipe": "bronze_arrow", "count": 5})
	_run(sim, 20)
	check_eq(_player(sim).inventory.count("bronze_arrow"), 30, "two batches of 15")
	check_eq(_player(sim).inventory.count("feather"), 0, "feathers used")


func test_fish_cook_on_a_campfire() -> void:
	var sim := _make_sim({"raw_sardine": 5})
	_set_level(sim, "cooking", 40)
	sim.skilling.add_station("fire", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "craft", {"kind": "cook", "recipe": "cooked_sardine", "count": 5})
	_run(sim, 30)
	check_eq(_player(sim).inventory.count("cooked_sardine"), 5, "cooked on the fire")


func test_smithing_makes_axes_and_arrowheads() -> void:
	var sim := _make_sim({"hammer": 1, "bronze_bar": 2})
	_set_level(sim, "smithing", 5)
	sim.skilling.add_station("anvil", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "craft", {"kind": "smith", "recipe": "bronze_axe", "count": 1})
	_run(sim, 8)
	sim.queue_item_action(PLAYER, "craft", {"kind": "smith", "recipe": "bronze_arrowheads", "count": 1})
	_run(sim, 8)
	check_eq(_player(sim).inventory.count("bronze_axe"), 1, "axe")
	check_eq(_player(sim).inventory.count("bronze_arrowheads"), 15, "arrowheads")


func test_starting_kit_has_gathering_tools() -> void:
	var sim := _make_sim()
	sim.give_starting_kit(PLAYER)
	for tool in ["bronze_axe", "small_net", "knife"]:
		check_eq(_player(sim).inventory.count(tool), 1, tool)
