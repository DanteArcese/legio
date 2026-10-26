extends "res://tests/test_case.gd"
## Garum: anchovies and salt ferment in the vat; garum makes better food.

const Simulation := preload("res://scripts/sim/simulation.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1


func _make_sim(items := {}, cooking := 1) -> Simulation:
	var sim := Simulation.new(6)
	sim.add_player(PLAYER)
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.skills.xp["cooking"] = player.skills.xp_for_level(cooking)
	for item_id in items:
		sim.give_item(PLAYER, item_id, items[item_id], "test", [])
	return sim


func _run(sim: Simulation, ticks: int) -> void:
	for i in ticks:
		sim.step()


func test_anchovies_and_salt_become_garum_at_the_vat() -> void:
	var sim := _make_sim({"raw_anchovy": 8, "salt": 4}, 15)
	sim.skilling.add_station("garum_vat", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "craft", {"kind": "garum", "recipe": "garum", "count": 5})
	_run(sim, 20)
	var player: RefCounted = sim.get_combatant(PLAYER)
	check_eq(player.inventory.count("garum"), 2, "two amphorae")
	check_eq(player.inventory.count("raw_anchovy"), 0, "anchovies used")
	check_eq(player.skills.xp["cooking"] - player.skills.xp_for_level(15), 120.0, "cooking xp")


func test_garum_needs_cooking_15_and_the_vat() -> void:
	var sim := _make_sim({"raw_anchovy": 4, "salt": 2}, 14)
	sim.skilling.add_station("garum_vat", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "craft", {"kind": "garum", "recipe": "garum", "count": 1})
	_run(sim, 8)
	check_eq(sim.get_combatant(PLAYER).inventory.count("garum"), 0, "too low")


func test_garum_dishes_heal_more_than_plain_fish() -> void:
	check(ContentDB.item("mackerel_in_garum")["heals"] > ContentDB.item("cooked_mackerel")["heals"], "garum mackerel beats plain")
	check(ContentDB.item("anchovies_in_garum")["heals"] > ContentDB.item("cooked_anchovy")["heals"], "relish beats plain anchovies")


func test_mackerel_in_garum_cooks_at_the_fire() -> void:
	var sim := _make_sim({"raw_mackerel": 2, "garum": 2}, 60)
	sim.skilling.add_station("fire", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "craft", {"kind": "cook", "recipe": "mackerel_in_garum", "count": 2})
	_run(sim, 12)
	check_eq(sim.get_combatant(PLAYER).inventory.count("mackerel_in_garum"), 2, "two glazed mackerel")


func test_the_merchant_sells_salt() -> void:
	var offers: Array = ContentDB.shop("gallic_merchant")["offers"]
	check(offers.any(func(o): return o["item"] == "salt"), "salt for sale")
