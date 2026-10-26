extends "res://tests/test_case.gd"
## Mercatura: taking, delivering, and abandoning trade contracts.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Mercatura := preload("res://scripts/sim/mercatura.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1


func _make_sim() -> Simulation:
	var sim := Simulation.new(16)
	sim.add_player(PLAYER)
	sim.mercatura.add_board("portus_board", Vector3(1, 0, 0))
	sim.add_shopkeeper("quartermaster", Vector3(-1, 0, 0))
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _do(sim: Simulation, action: String, args := {}) -> Array:
	sim.queue_item_action(PLAYER, action, args)
	return sim.step()


func test_garum_for_the_cohort() -> void:
	var sim := _make_sim()
	var player := _player(sim)
	_do(sim, "take_contract", {"board": "portus_board", "contract": "garum_for_the_cohort"})
	check_eq(player.trade_contract, {"id": "garum_for_the_cohort"}, "contract taken")
	var events := _do(sim, "deliver_contract", {"shop": "quartermaster"})
	check(events.any(func(e): return e["type"] == "message" and "You need 3 garum" in e["text"]), "needs the garum first")
	sim.give_item(PLAYER, "garum", 3, "test", [])
	_do(sim, "deliver_contract", {"shop": "quartermaster"})
	check(player.trade_contract.is_empty(), "delivered")
	check_eq(player.inventory.count("garum"), 0, "garum handed over")
	check_eq(player.inventory.count("coins"), 240, "paid")
	check_eq(player.skills.xp["mercatura"], 90.0, "mercatura xp")
	check_eq(player.contracts_done, 1, "counted")


func test_one_contract_at_a_time() -> void:
	var sim := _make_sim()
	_do(sim, "take_contract", {"board": "portus_board", "contract": "garum_for_the_cohort"})
	var events := _do(sim, "take_contract", {"board": "portus_board", "contract": "salt_for_the_fort"})
	check(events.any(func(e): return e["type"] == "message" and "current contract" in e["text"]), "refused")
	_do(sim, "abandon_contract")
	_do(sim, "take_contract", {"board": "portus_board", "contract": "salt_for_the_fort"})
	check_eq(_player(sim).trade_contract["id"], "salt_for_the_fort", "the new one after abandoning")


func test_bigger_contracts_need_levels() -> void:
	var sim := _make_sim()
	check(not Mercatura.contracts_on("portus_board", 1).has("tuna_for_the_forum"), "hidden at level 1")
	check(Mercatura.contracts_on("portus_board", 15).has("tuna_for_the_forum"), "offered at 15")
	var events := _do(sim, "take_contract", {"board": "portus_board", "contract": "tuna_for_the_forum"})
	check(events.any(func(e): return e["type"] == "message" and "Mercatura 15" in e["text"]), "level gate")


func test_delivering_to_the_wrong_shop_does_nothing() -> void:
	var sim := _make_sim()
	sim.add_shopkeeper("fishmonger", Vector3(0, 0, 1))
	sim.give_item(PLAYER, "garum", 3, "test", [])
	_do(sim, "take_contract", {"board": "portus_board", "contract": "garum_for_the_cohort"})
	_do(sim, "deliver_contract", {"shop": "fishmonger"})
	check(not _player(sim).trade_contract.is_empty(), "still open")
	check_eq(_player(sim).inventory.count("garum"), 3, "kept the garum")


func test_a_contract_survives_a_save() -> void:
	var sim := _make_sim()
	_do(sim, "take_contract", {"board": "portus_board", "contract": "salt_for_the_fort"})
	var data := SaveGame.from_json(SaveGame.to_json(SaveGame.capture(sim, PLAYER)))
	var loaded := _make_sim()
	SaveGame.restore(loaded, PLAYER, data)
	check_eq(_player(loaded).trade_contract, {"id": "salt_for_the_fort"}, "still carrying the contract")
