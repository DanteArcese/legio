extends "res://tests/test_case.gd"
## The forum market: prices move with every unit traded and drift back to
## value, the broker takes a cut, only tradeable goods and only near the
## broker, never for a Solitarius, and prices are kept in the save.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Market := preload("res://scripts/sim/market.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1


func _make_sim() -> Simulation:
	var sim := Simulation.new(2)
	sim.add_player(PLAYER)
	sim.market.add_broker(Vector3(1, 0, 0))
	sim.give_item(PLAYER, "coins", 10000, "test", [])
	return sim


func _act(sim: Simulation, action: String, args: Dictionary) -> Array:
	sim.queue_item_action(PLAYER, action, args)
	return sim.step()


func test_selling_lowers_the_price_and_buying_raises_it() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	var value: int = ContentDB.item("iron_bar")["value"]
	check_eq(sim.market.price("iron_bar"), value, "starts at its value")
	sim.give_item(PLAYER, "iron_bar", 10, "test", [])
	var coins: int = player.inventory.count("coins")
	var expected: int = sim.market.sell_return("iron_bar", 10)
	_act(sim, "market_sell", {"item": "iron_bar", "quantity": 0})
	check_eq(player.inventory.count("iron_bar"), 0, "sold all ten")
	check_eq(player.inventory.count("coins"), coins + expected, "for what the market quoted")
	check(expected < value * 10 * 0.9, "each bar fetching less than the last")
	check(sim.market.price("iron_bar") < value, "the price fell")
	var low: int = sim.market.price("iron_bar")
	_act(sim, "market_buy", {"item": "iron_bar", "quantity": 5})
	check_eq(player.inventory.count("iron_bar"), 5, "bought five")
	check(sim.market.price("iron_bar") > low, "and the price rose")


func test_prices_drift_back() -> void:
	var sim := _make_sim()
	sim.market.prices["iron_bar"] = 0.5
	for i in Market.DRIFT_TICKS * 30:
		sim.step()
	check(not sim.market.prices.has("iron_bar") or absf(sim.market.prices["iron_bar"] - 1.0) < 0.05, "back near value (%s)" % [sim.market.prices])


func test_bounds_and_the_spread() -> void:
	var sim := _make_sim()
	sim.market.prices["bread"] = 100.0
	sim.market.prices["bread"] = minf(sim.market.prices["bread"], Market.HIGHEST)
	check(sim.market.buy_cost("pearl", 1) > sim.market.sell_return("pearl", 1), "buying costs more than selling fetches")
	sim.give_item(PLAYER, "bread", 28, "test", [])
	for i in 3:
		_act(sim, "market_sell", {"item": "bread", "quantity": 0})
		sim.give_item(PLAYER, "bread", 20, "test", [])
	check(sim.market.multiple("bread") >= Market.LOWEST, "never below the floor")


func test_who_and_what_can_trade() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	check(not Market.tradeable("coins"), "not money")
	check(not Market.tradeable("legion_eagle") or not ContentDB.item("legion_eagle").get("quest_item", false), "not quest items")
	check(Market.tradeable("bread"), "bread, yes")
	player.position = Vector3(50, 0, 0)
	_act(sim, "market_buy", {"item": "bread", "quantity": 1})
	check_eq(player.inventory.count("bread"), 0, "only at the broker")
	player.position = Vector3.ZERO
	player.account_mode = "solitarius"
	var events := _act(sim, "market_buy", {"item": "bread", "quantity": 1})
	check_eq(player.inventory.count("bread"), 0, "not for a Solitarius")
	check(events.any(func(e): return e["type"] == "message" and "Solitarius" in e["text"]), "who is told why")


func test_prices_are_saved() -> void:
	var sim := _make_sim()
	sim.market.prices["iron_bar"] = 0.62
	var text := SaveGame.to_json(SaveGame.capture(sim, PLAYER))
	var fresh := Simulation.new(2)
	fresh.add_player(PLAYER)
	check(SaveGame.restore(fresh, PLAYER, SaveGame.from_json(text)), "restored")
	check(is_equal_approx(fresh.market.multiple("iron_bar"), 0.62), "the iron price kept")
