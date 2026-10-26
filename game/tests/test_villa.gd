extends "res://tests/test_case.gd"
## The villa: buying it as a citizen, and building working furniture.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Villa := preload("res://scripts/sim/villa.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1


func _make_sim(citizen := true) -> Simulation:
	var sim := Simulation.new(17)
	sim.add_player(PLAYER)
	var player: RefCounted = sim.get_combatant(PLAYER)
	if citizen:
		player.quests["decurio"] = {"step": 3, "progress": 0, "done": true}
	sim.villa.set_surveyor(Vector3(1, 0, 0))
	for spec in [["hearth", "hearth"], ["shrine", "shrine"], ["strongbox", "strongbox"], ["garden_1", "garden"]]:
		sim.villa.add_hotspot(spec[0], spec[1], Vector3(0, 0, 1))
	sim.give_item(PLAYER, "hammer", 1, "test", [])
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _do(sim: Simulation, action: String, args := {}) -> Array:
	sim.queue_item_action(PLAYER, action, args)
	return sim.step()


func test_only_citizens_buy_villas() -> void:
	var sim := _make_sim(false)
	sim.give_item(PLAYER, "coins", 6000, "test", [])
	var events := _do(sim, "buy_villa")
	check(events.any(func(e): return e["type"] == "message" and "citizens" in e["text"]), "citizens only")
	check(not _player(sim).villa_owned, "not bought")


func test_a_citizen_buys_a_villa() -> void:
	var sim := _make_sim()
	sim.give_item(PLAYER, "coins", 6000, "test", [])
	_do(sim, "buy_villa")
	check(_player(sim).villa_owned, "owned")
	check_eq(_player(sim).inventory.count("coins"), 1000, "paid 5000")


func test_a_campfire_on_the_hearth_cooks() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	player.villa_owned = true
	sim.give_item(PLAYER, "plank", 3, "test", [])
	sim.give_item(PLAYER, "raw_sardine", 1, "test", [])
	_do(sim, "build", {"hotspot": "hearth", "furniture": "villa_campfire"})
	check_eq(player.villa_furniture.get("hearth"), "villa_campfire", "built")
	check_eq(player.inventory.count("plank"), 0, "planks used")
	check_eq(player.skills.xp["engineering"], 30.0, "engineering xp")
	sim.queue_item_action(PLAYER, "craft", {"kind": "cook", "recipe": "cooked_sardine", "count": 1})
	for i in 6:
		sim.step()
	check_eq(player.inventory.count("cooked_sardine") + player.inventory.count("burnt_food"), 1, "the campfire cooks")


func test_building_needs_level_materials_and_a_hammer() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	player.villa_owned = true
	var events := _do(sim, "build", {"hotspot": "strongbox", "furniture": "villa_strongbox"})
	check(events.any(func(e): return e["type"] == "message" and "Engineering 30" in e["text"]), "level gate")
	events = _do(sim, "build", {"hotspot": "hearth", "furniture": "villa_campfire"})
	check(events.any(func(e): return e["type"] == "message" and "plank" in e["text"]), "needs planks")
	player.inventory.remove("hammer", 1)
	sim.give_item(PLAYER, "plank", 3, "test", [])
	events = _do(sim, "build", {"hotspot": "hearth", "furniture": "villa_campfire"})
	check(events.any(func(e): return e["type"] == "message" and "hammer" in e["text"]), "needs a hammer")


func test_strongbox_lararium_and_garden_work() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	player.villa_owned = true
	player.skills.xp["engineering"] = player.skills.xp_for_level(40)
	for item in [["oak_plank", 10], ["iron_bar", 2], ["plank", 10], ["bronze_nails", 15]]:
		sim.give_item(PLAYER, item[0], item[1], "test", [])
	_do(sim, "build", {"hotspot": "strongbox", "furniture": "villa_strongbox"})
	_do(sim, "build", {"hotspot": "shrine", "furniture": "lararium"})
	_do(sim, "build", {"hotspot": "garden_1", "furniture": "herb_bed"})
	check(sim.items.banks.has(Vector3(0, 0, 1)), "the strongbox is a bank")
	check(sim.pietas.altars.any(func(a): return a["position"] == Vector3(0, 0, 1)), "the lararium is an altar")
	check(sim.farming.patches.has(Villa.patch_id(sim.villa.hotspots["garden_1"])), "the bed is a herb patch")
	_do(sim, "remove_furniture", {"hotspot": "strongbox"})
	check(not sim.items.banks.has(Vector3(0, 0, 1)), "removed")
	check(not player.villa_furniture.has("strongbox"), "cleared")


func test_the_villa_survives_a_save() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	player.villa_owned = true
	sim.give_item(PLAYER, "plank", 3, "test", [])
	_do(sim, "build", {"hotspot": "hearth", "furniture": "villa_campfire"})
	var data := SaveGame.from_json(SaveGame.to_json(SaveGame.capture(sim, PLAYER)))
	var loaded := _make_sim()
	SaveGame.restore(loaded, PLAYER, data)
	check(_player(loaded).villa_owned, "still owned")
	check_eq(_player(loaded).villa_furniture.get("hearth"), "villa_campfire", "the campfire is still there")
	check(loaded.skilling.stations.any(func(s): return s["kind"] == "fire" and s["position"] == Vector3(0, 0, 1)), "and still cooks")


func test_sawing_planks() -> void:
	var sim := _make_sim()
	sim.skilling.add_station("sawpit", Vector3(0.5, 0, 0))
	sim.give_item(PLAYER, "logs", 2, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "saw", "recipe": "plank", "count": 2})
	for i in 12:
		sim.step()
	check_eq(_player(sim).inventory.count("plank"), 2, "two planks")
