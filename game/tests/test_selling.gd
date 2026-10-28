extends "res://tests/test_case.gd"
## Selling to shops: specialists pay more for their trade, the Gaulish
## merchant buys anything for less, and some things can't be sold.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Items := preload("res://scripts/sim/items.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1


func _make_sim() -> Simulation:
	var sim := Simulation.new(2)
	sim.add_player(PLAYER)
	for shop_id in ["gallic_merchant", "aulus", "procurator"]:
		sim.add_shopkeeper(shop_id, Vector3(1, 0, 0))
	return sim


func _sell(sim: Simulation, shop_id: String, item_id: String) -> Array:
	sim.queue_item_action(PLAYER, "sell", {"shop": shop_id, "item": item_id})
	return sim.step()


func test_selling_pays_coins_for_every_one_carried() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	sim.give_item(PLAYER, "wolf_pelt", 3, "test", [])
	_sell(sim, "aulus", "wolf_pelt")
	check_eq(player.inventory.count("wolf_pelt"), 0, "all sold")
	check_eq(player.inventory.count("coins"), Items.sell_price("aulus", "wolf_pelt") * 3, "paid for three")


func test_specialists_pay_more_than_the_merchant() -> void:
	check(Items.sell_price("procurator", "silver_bar") > Items.sell_price("gallic_merchant", "silver_bar"), "procurator for silver")
	check(Items.sell_price("aulus", "wolf_pelt") > Items.sell_price("gallic_merchant", "wolf_pelt"), "Aulus for pelts")
	check_eq(Items.sell_price("gallic_merchant", "silver_bar"), floori(ContentDB.item("silver_bar")["value"] * 0.4), "the merchant pays 40%")


func test_specialists_only_buy_their_trade() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	sim.give_item(PLAYER, "pearl", 1, "test", [])
	var events := _sell(sim, "procurator", "pearl")
	check_eq(player.inventory.count("pearl"), 1, "kept")
	check(events.any(func(e): return e["type"] == "message" and "won't buy" in e["text"]), "told why")
	_sell(sim, "gallic_merchant", "pearl")
	check_eq(player.inventory.count("pearl"), 0, "the merchant buys anything")


func test_some_things_cannot_be_sold() -> void:
	for item_id in ["coins", "legion_eagle", "mole", "diploma", "burnt_food"]:
		check_eq(Items.sell_price("gallic_merchant", item_id), 0, "%s can't be sold" % item_id)


func test_selling_needs_the_shopkeeper_nearby() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.position = Vector3(40, 0, 40)
	sim.give_item(PLAYER, "wolf_pelt", 1, "test", [])
	_sell(sim, "aulus", "wolf_pelt")
	check_eq(player.inventory.count("wolf_pelt"), 1, "too far away")


func test_the_ferry_fare_is_paid_once_and_only_if_carried() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	sim.give_item(PLAYER, "coins", 30, "test", [])
	sim.queue_item_action(PLAYER, "pay_fare", {"amount": 25})
	sim.step()
	check_eq(player.inventory.count("coins"), 5, "paid 25")
	sim.queue_item_action(PLAYER, "pay_fare", {"amount": 25})
	sim.step()
	check_eq(player.inventory.count("coins"), 5, "can't pay what you don't have")


func test_messages_use_the_right_article() -> void:
	check_eq(Items._with_article("needle"), "a needle", "a")
	check_eq(Items._with_article("iron axe"), "an iron axe", "an")
	check_eq(Items._with_article("olives"), "some olives", "plural")


func test_regional_demand_pays_its_own_price() -> void:
	var wine: int = ContentDB.item("estate_wine")["value"]
	check_eq(Items.sell_price("gallic_merchant", "estate_wine"), floori(wine * 1.2), "the Gauls pay over the odds for wine")
	check(Items.sell_price("gallic_merchant", "estate_wine") > Items.sell_price("fishmonger", "estate_wine"), "better inland than at the harbour")
	check(Items.sell_price("procurator", "bread") > 0, "the mines buy bread")
	check(Items.sell_price("fishmonger", "olive_oil") > Items.sell_price("procurator", "olive_oil"), "oil is worth most at the harbour")
