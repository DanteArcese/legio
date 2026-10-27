extends "res://tools/playtest/scenario.gd"
## Mercatura: a trade run. At Portus Salis, buy garum from the fishmonger
## and take the garum contract off the trade board; take the road to the
## fort and deliver it to the quartermaster for coins and XP.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	driver().sim.give_item(PLAYER, "coins", 200, "test", [])
	# Start at the harbour, as if fresh off the road.
	player()._arrive_through(main.get_node("RoadToPortus"))
	await seconds(0.5)
	await walk_to(Vector3(-300, 0, -12), 0.6, 60.0)

	var fishmonger: Node3D = main.get_node("PortusSalis/Fishmonger")
	for i in 3:
		var buy: Array = WorldMenu.wares_for(player(), fishmonger).filter(func(o): return o[0].begins_with("Buy garum"))
		if buy.size() == 1:
			buy[0][1].call()
		await _wait_until(func(): return me.inventory.count("garum") == i + 1, 15.0)
	expect(me.inventory.count("garum") == 3, "bought three garum at the coast")

	var board: Node3D = main.get_node("PortusSalis/PortusBoard")
	var take: Array = WorldMenu.options_for(player(), board).filter(func(o): return o[0].begins_with("Take: Garum for the cohort"))
	expect(take.size() == 1, "the board offers the garum contract")
	if take.size() == 1:
		take[0][1].call()
	await _wait_until(func(): return not me.trade_contract.is_empty(), 20.0)
	expect(me.trade_contract.get("id") == "garum_for_the_cohort", "contract taken")
	await press("quest_log")
	expect("Trade contract: Garum for the cohort" in main.get_node("QuestUi").log_text(), "the quest log tracks the contract")
	await shot("contract")
	await press("quest_log")

	await walk_to(Vector3(-300, 0, -44), 0.6, 90.0)
	player().travel(main.get_node("PortusSalis/RoadToFort"))
	await _wait_until(func(): return player().global_position.x > -50.0, 30.0)
	var optio: Node3D = main.get_node("OptioGaius")
	await route_to(optio.global_position + Vector3(0, 0, -1.5), 1.0, 180.0)
	var deliver: Array = WorldMenu.options_for(player(), optio).filter(func(o): return o[0] == "Deliver contract cargo")
	expect(deliver.size() == 1, "the quartermaster takes delivery")
	var coins_before: int = me.inventory.count("coins")
	if deliver.size() == 1:
		deliver[0][1].call()
	await _wait_until(func(): return me.trade_contract.is_empty(), 20.0)
	expect(me.trade_contract.is_empty() and me.inventory.count("coins") == coins_before + 240, "paid 240 denarii")
	expect(me.skills.xp["mercatura"] > 0.0, "Mercatura XP")


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
