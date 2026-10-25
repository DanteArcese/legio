extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skilling := preload("res://scripts/sim/skilling.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const ROCK := 1


func _make_sim(kit := true) -> Simulation:
	var sim := Simulation.new(21)
	sim.add_player(PLAYER)
	if kit:
		sim.give_item(PLAYER, "bronze_pickaxe", 1, "test", [])
		sim.give_item(PLAYER, "hammer", 1, "test", [])
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _run(sim: Simulation, ticks: int) -> Array:
	var events := []
	for i in ticks:
		events.append_array(sim.step())
	return events


func test_mining_yields_ore_xp_and_depletes_the_rock() -> void:
	var sim := _make_sim()
	sim.skilling.add_rock(ROCK, "copper_rock", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "mine", {"rock": ROCK})
	var events := _run(sim, 60)
	check_eq(_player(sim).inventory.count("copper_ore"), 1, "one ore per rock")
	check_eq(_player(sim).skills.xp["mining"], 15.0, "mining xp")
	check(events.any(func(e): return e["type"] == "rock_depleted"), "depleted")
	check(events.any(func(e): return e["type"] == "rock_respawned"), "respawned later")
	check(_player(sim).skill_action.is_empty(), "action ended")


func test_mining_needs_a_pickaxe_and_the_level() -> void:
	var sim := _make_sim(false)
	sim.skilling.add_rock(ROCK, "copper_rock", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "mine", {"rock": ROCK})
	var events := sim.step()
	check(events.any(func(e): return e["type"] == "message" and "pickaxe" in e["text"]), "needs pickaxe")
	sim.give_item(PLAYER, "bronze_pickaxe", 1, "test", [])
	sim.skilling.add_rock(2, "iron_rock", Vector3(0, 0, 1))
	sim.queue_item_action(PLAYER, "mine", {"rock": 2})
	events = sim.step()
	check(events.any(func(e): return e["type"] == "message" and "Mining 15" in e["text"]), "needs level 15")


func test_walking_away_stops_mining() -> void:
	var sim := _make_sim()
	sim.skilling.add_rock(ROCK, "iron_rock", Vector3(1, 0, 0))
	_player(sim).skills.xp["mining"] = Skills.xp_for_level(15)
	sim.queue_item_action(PLAYER, "mine", {"rock": ROCK})
	sim.step()
	check(not _player(sim).skill_action.is_empty(), "mining")
	sim.set_position(PLAYER, Vector3(10, 0, 0))
	sim.step()
	check(_player(sim).skill_action.is_empty(), "stopped")


func test_attacking_stops_skilling() -> void:
	var sim := _make_sim()
	sim.skilling.add_rock(ROCK, "copper_rock", Vector3(1, 0, 0))
	sim.add_monster(50, "rat", Vector3(0, 0, 1))
	sim.queue_item_action(PLAYER, "mine", {"rock": ROCK})
	sim.step()
	sim.queue_attack(PLAYER, 50)
	sim.step()
	check(_player(sim).skill_action.is_empty(), "stopped mining to fight")


func test_mine_chance_grows_with_level_and_pickaxe() -> void:
	var iron := ContentDB.rock("iron_rock")
	check(Skilling.mine_chance(30, iron, 1) > Skilling.mine_chance(15, iron, 1), "level helps")
	check(Skilling.mine_chance(15, iron, 2) > Skilling.mine_chance(15, iron, 1), "better pickaxe helps")
	check_eq(Skilling.mine_chance(99, iron, 2), 0.95, "capped")


func test_iron_pickaxe_needs_mining_10() -> void:
	var sim := _make_sim(false)
	sim.give_item(PLAYER, "iron_pickaxe", 1, "test", [])
	check_eq(Skilling.tool_tier(_player(sim), "pickaxe"), 0, "can't use it yet")
	_player(sim).skills.xp["mining"] = Skills.xp_for_level(10)
	check_eq(Skilling.tool_tier(_player(sim), "pickaxe"), 2, "tier 2 at 10")


func test_smelting_bronze_uses_both_ores() -> void:
	var sim := _make_sim()
	sim.skilling.add_station("furnace", Vector3(1, 0, 0))
	sim.give_item(PLAYER, "copper_ore", 3, "test", [])
	sim.give_item(PLAYER, "tin_ore", 2, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "smelt", "recipe": "bronze_bar", "count": 10})
	var events := _run(sim, 20)
	var inv: RefCounted = _player(sim).inventory
	check_eq(inv.count("bronze_bar"), 2, "two bars")
	check_eq(inv.count("copper_ore"), 1, "one copper left")
	check_eq(inv.count("tin_ore"), 0, "tin used up")
	check_eq(_player(sim).skills.xp["smithing"], 12.0, "smithing xp")
	check(events.any(func(e): return e["type"] == "message" and "materials" in e["text"]), "stopped when out")


func test_crafting_needs_the_right_station_nearby() -> void:
	var sim := _make_sim()
	sim.skilling.add_station("anvil", Vector3(1, 0, 0))
	sim.give_item(PLAYER, "copper_ore", 1, "test", [])
	sim.give_item(PLAYER, "tin_ore", 1, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "smelt", "recipe": "bronze_bar", "count": 1})
	_run(sim, 10)
	check_eq(_player(sim).inventory.count("bronze_bar"), 0, "an anvil is not a furnace")


func test_smithing_needs_a_hammer_and_level() -> void:
	var sim := _make_sim(false)
	sim.skilling.add_station("anvil", Vector3(1, 0, 0))
	sim.give_item(PLAYER, "bronze_bar", 3, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "smith", "recipe": "bronze_gladius", "count": 1})
	var events := sim.step()
	check(events.any(func(e): return e["type"] == "message" and "Smithing 5" in e["text"]), "needs level 5")
	sim.queue_item_action(PLAYER, "craft", {"kind": "smith", "recipe": "bronze_pugio", "count": 1})
	events = sim.step()
	check(events.any(func(e): return e["type"] == "message" and "hammer" in e["text"]), "needs hammer")
	sim.give_item(PLAYER, "hammer", 1, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "smith", "recipe": "bronze_pugio", "count": 1})
	_run(sim, 6)
	check_eq(_player(sim).inventory.count("bronze_pugio"), 1, "made a pugio")
	check_eq(_player(sim).inventory.count("bronze_bar"), 2, "used one bar")


func test_burn_chance_falls_to_zero_at_stop_level() -> void:
	var meat := ContentDB.recipe("cook", "cooked_meat")
	check(is_equal_approx(Skilling.burn_chance(1, meat), Skilling.MAX_BURN_CHANCE), "max at level 1")
	check(Skilling.burn_chance(15, meat) < Skilling.burn_chance(5, meat), "falls with level")
	check_eq(Skilling.burn_chance(30, meat), 0.0, "never burns at 30")


func test_cooking_burns_some_at_low_level_and_none_at_stop_level() -> void:
	for level in [1, 30]:
		var sim := _make_sim()
		sim.skilling.add_station("range", Vector3(1, 0, 0))
		_player(sim).skills.xp["cooking"] = Skills.xp_for_level(level)
		sim.give_item(PLAYER, "raw_meat", 20, "test", [])
		sim.queue_item_action(PLAYER, "craft", {"kind": "cook", "recipe": "cooked_meat", "count": 20})
		_run(sim, 100)
		var inv: RefCounted = _player(sim).inventory
		check_eq(inv.count("cooked_meat") + inv.count("burnt_food"), 20, "all 20 cooked or burnt at %d" % level)
		if level == 1:
			check(inv.count("burnt_food") >= 6, "burns plenty at level 1 (%d)" % inv.count("burnt_food"))
		else:
			check_eq(inv.count("burnt_food"), 0, "no burning at 30")


func test_iron_smelting_sometimes_fails() -> void:
	var sim := _make_sim()
	sim.skilling.add_station("furnace", Vector3(1, 0, 0))
	_player(sim).skills.xp["smithing"] = Skills.xp_for_level(15)
	sim.give_item(PLAYER, "iron_ore", 20, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "smelt", "recipe": "iron_bar", "count": 20})
	_run(sim, 100)
	var bars: int = _player(sim).inventory.count("iron_bar")
	check(bars > 4 and bars < 16, "about half succeed (%d of 20)" % bars)
	check_eq(_player(sim).inventory.count("iron_ore"), 0, "all ore used")
