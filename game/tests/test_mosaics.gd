extends "res://tests/test_case.gd"
## Marble and mosaics: tesserae cut from Parian marble with a chisel, a
## mosaic floor at the villa, and resting on it for a little extra XP.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Villa := preload("res://scripts/sim/villa.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1


func _make_sim() -> Simulation:
	var sim := Simulation.new(11)
	sim.add_player(PLAYER)
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.villa_owned = true
	player.skills.xp["engineering"] = player.skills.xp_for_level(50)
	player.skills.xp["crafting"] = player.skills.xp_for_level(45)
	sim.villa.add_hotspot("atrium", "atrium", Vector3(0, 0, 1))
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _do(sim: Simulation, action: String, args := {}) -> Array:
	sim.queue_item_action(PLAYER, action, args)
	return sim.step()


func _lay_mosaic(sim: Simulation) -> void:
	sim.give_item(PLAYER, "hammer", 1, "test", [])
	for entry in ContentDB.furniture("mosaic_floor")["materials"]:
		sim.give_item(PLAYER, entry["item"], entry["quantity"], "test", [])
	_do(sim, "build", {"hotspot": "atrium", "furniture": "mosaic_floor"})


func test_a_chisel_cuts_marble_into_tesserae() -> void:
	var sim := _make_sim()
	sim.give_item(PLAYER, "marble_block", 2, "test", [])
	_do(sim, "craft", {"kind": "masonry", "recipe": "tesserae", "count": 2})
	for i in 8:
		sim.step()
	check_eq(_player(sim).inventory.count("tesserae"), 0, "no chisel, no tesserae")
	sim.give_item(PLAYER, "chisel", 1, "test", [])
	_do(sim, "craft", {"kind": "masonry", "recipe": "tesserae", "count": 2})
	for i in 10:
		sim.step()
	check_eq(_player(sim).inventory.count("tesserae"), 50, "25 a block")


func test_resting_on_the_mosaic_adds_five_percent_xp() -> void:
	var sim := _make_sim()
	_lay_mosaic(sim)
	check_eq(_player(sim).villa_furniture.get("atrium", ""), "mosaic_floor", "laid the mosaic")
	var before: float = _player(sim).skills.xp["mining"]
	sim.award_xp(_player(sim), "mining", 100.0, [])
	check(is_equal_approx(_player(sim).skills.xp["mining"] - before, 100.0), "plain xp before resting")
	var events := _do(sim, "rest", {"hotspot": "atrium"})
	check(events.any(func(e): return e["type"] == "rested"), "rested")
	before = _player(sim).skills.xp["mining"]
	sim.award_xp(_player(sim), "mining", 100.0, [])
	check(is_equal_approx(_player(sim).skills.xp["mining"] - before, 105.0), "+5% while rested")
	for i in Villa.REST_TICKS:
		sim.step()
	before = _player(sim).skills.xp["mining"]
	sim.award_xp(_player(sim), "mining", 100.0, [])
	check(is_equal_approx(_player(sim).skills.xp["mining"] - before, 100.0), "wears off")


func test_no_mosaic_no_rest() -> void:
	var sim := _make_sim()
	var events := _do(sim, "rest", {"hotspot": "atrium"})
	check(not events.any(func(e): return e["type"] == "rested"), "nothing to rest on")


func test_rest_survives_a_save() -> void:
	var sim := _make_sim()
	_lay_mosaic(sim)
	_do(sim, "rest", {"hotspot": "atrium"})
	for i in 100:
		sim.step()
	var data := SaveGame.from_json(SaveGame.to_json(SaveGame.capture(sim, PLAYER)))
	var other := _make_sim()
	SaveGame.restore(other, PLAYER, data)
	var left: int = _player(other).rested_until - other.tick
	check(left > Villa.REST_TICKS - 110 and left <= Villa.REST_TICKS - 100, "the rest left carries over (%d)" % left)
