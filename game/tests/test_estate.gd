extends "res://tests/test_case.gd"
## The villa estate: presses that make oil and wine, a vine trellis, and a
## steward who runs the presses on real time.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Villa := preload("res://scripts/sim/villa.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const HOUR := 3600.0
const NOW := 1_800_000_000.0


func _make_sim() -> Simulation:
	var sim := Simulation.new(17)
	sim.add_player(PLAYER)
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.villa_owned = true
	player.skills.xp["engineering"] = player.skills.xp_for_level(45)
	player.skills.xp["cooking"] = player.skills.xp_for_level(40)
	player.skills.xp["farming"] = player.skills.xp_for_level(25)
	for spec in [["press_1", "press"], ["press_2", "press"], ["office", "office"], ["garden_1", "garden"]]:
		sim.villa.add_hotspot(spec[0], spec[1], Vector3(0, 0, 1))
	sim.give_item(PLAYER, "hammer", 1, "test", [])
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _do(sim: Simulation, action: String, args := {}) -> Array:
	sim.queue_item_action(PLAYER, action, args)
	return sim.step()


func _build(sim: Simulation, hotspot: String, furniture: String, now := NOW) -> void:
	for entry in ContentDB.furniture(furniture)["materials"]:
		sim.give_item(PLAYER, entry["item"], entry["quantity"], "test", [])
	_do(sim, "build", {"hotspot": hotspot, "furniture": furniture, "now": now})
	check_eq(_player(sim).villa_furniture.get(hotspot, ""), furniture, "built %s" % furniture)


func test_the_olive_press_makes_oil() -> void:
	var sim := _make_sim()
	_build(sim, "press_1", "olive_press")
	sim.give_item(PLAYER, "olives", 8, "test", [])
	_do(sim, "craft", {"kind": "press_oil", "recipe": "olive_oil", "count": 2})
	for i in 12:
		sim.step()
	check_eq(_player(sim).inventory.count("olive_oil"), 2, "two amphorae from eight olives")
	check(_player(sim).skills.xp["cooking"] > _player(sim).skills.xp_for_level(40), "cooking xp")


func test_no_press_no_wine() -> void:
	var sim := _make_sim()
	sim.give_item(PLAYER, "grapes", 5, "test", [])
	_do(sim, "craft", {"kind": "press_wine", "recipe": "estate_wine", "count": 1})
	for i in 8:
		sim.step()
	check_eq(_player(sim).inventory.count("estate_wine"), 0, "needs a wine press")


func test_vines_grow_on_a_trellis() -> void:
	var sim := _make_sim()
	_build(sim, "garden_1", "vine_trellis")
	var patch: Dictionary = sim.farming.patches[Villa.patch_id(sim.villa.hotspots["garden_1"])]
	check_eq(ContentDB.patch(patch["type"])["kind"], "vine", "a vine patch")
	check_eq(ContentDB.crop("grapes")["seed"], "vine_cutting", "grown from cuttings")


func test_the_steward_needs_a_press() -> void:
	var sim := _make_sim()
	_build(sim, "office", "steward_desk")
	check_eq(_player(sim).inventory.count("coins"), 0, "his hire is paid up front")
	var events := _do(sim, "collect_estate", {"now": NOW + 10 * HOUR})
	check(events.any(func(e): return e["type"] == "message" and "press" in e["text"]), "nothing without a press")


func test_the_steward_fills_an_amphora_per_press_every_two_hours() -> void:
	var sim := _make_sim()
	_build(sim, "press_1", "olive_press")
	_build(sim, "press_2", "wine_press")
	_build(sim, "office", "steward_desk")
	var events := _do(sim, "collect_estate", {"now": NOW + 1 * HOUR})
	check(events.any(func(e): return e["type"] == "message" and "minutes" in e["text"]), "nothing yet after an hour")
	_do(sim, "collect_estate", {"now": NOW + 5 * HOUR})
	check_eq(_player(sim).inventory.count("olive_oil"), 2, "two oil after five hours")
	check_eq(_player(sim).inventory.count("estate_wine"), 2, "two wine")
	# The odd hour carries over.
	_do(sim, "collect_estate", {"now": NOW + 6 * HOUR})
	check_eq(_player(sim).inventory.count("olive_oil"), 3, "the leftover hour counted")


func test_the_steward_keeps_at_most_a_day() -> void:
	var sim := _make_sim()
	_build(sim, "press_1", "olive_press")
	_build(sim, "office", "steward_desk")
	_do(sim, "collect_estate", {"now": NOW + 72 * HOUR})
	check_eq(_player(sim).inventory.count("olive_oil"), 12, "a day's worth, no more")
	_do(sim, "collect_estate", {"now": NOW + 73 * HOUR})
	check_eq(_player(sim).inventory.count("olive_oil"), 12, "the clock restarted at collection")


func test_the_stewards_books_survive_a_save() -> void:
	var sim := _make_sim()
	_build(sim, "press_1", "olive_press")
	_build(sim, "office", "steward_desk")
	var data := SaveGame.from_json(SaveGame.to_json(SaveGame.capture(sim, PLAYER)))
	var other := _make_sim()
	SaveGame.restore(other, PLAYER, data)
	check_eq(_player(other).steward_since, NOW, "start time saved")
	_do(other, "collect_estate", {"now": NOW + 4 * HOUR})
	check_eq(_player(other).inventory.count("olive_oil"), 2, "collects after loading")


func test_mercatura_wants_estate_goods() -> void:
	var items: Array = ContentDB.data()["mercatura"]["contracts"].values().map(func(c): return c["item"])
	check(items.has("olive_oil") and items.has("estate_wine"), "contracts for oil and wine")
