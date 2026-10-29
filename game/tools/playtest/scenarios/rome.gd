extends "res://tools/playtest/scenario.gd"
## Rome: the ship at Portus Salis turns a peregrinus away; a citizen pays the
## fare and sails up the Tiber, walks the street to the forum, opens the
## bank, takes a contract from the capital's venator, buys from the dealer,
## and sails home.

const PLAYER := 1
const Skills := preload("res://scripts/sim/skills.gd")
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var ship: Node3D = main.get_node("PortusSalis/ShipToRome")
	driver().sim.give_item(PLAYER, "coins", 200, "test", [])
	player().destination = null
	player().global_position = Vector3(-300, 1.35, 21)
	await seconds(1.0)
	player().travel(ship)
	await seconds(2.5)
	expect(player().global_position.x > -400.0, "a peregrinus isn't taken aboard")

	me.quests["decurio"] = {"step": 0, "done": true}
	for skill in ["attack", "strength", "defence", "vitality", "slayer"]:
		me.skills.xp[skill] = Skills.xp_for_level(80)
	var coins: int = me.inventory.count("coins")
	player().travel(ship)
	await _wait_until(func(): return player().global_position.x < -500.0, 20.0)
	expect(player().global_position.x < -500.0, "a citizen sails to Rome")
	await seconds(1.0)
	expect(me.inventory.count("coins") == coins - 60, "the fare is 60 denarii")
	expect(main.get_node("WorldMap").region_at(player().global_position) == "Rome", "the map says Rome")
	expect(main.get_node("Music").style == "rome", "Rome's music (%s)" % main.get_node("Music").style)
	expect(main.get_node("Sound").zone == "town", "a city's murmur, not surf (%s)" % main.get_node("Sound").zone)
	await shot("quay")

	expect(await walk_to(Vector3(-590, 0, 4), 1.0, 60.0), "up the street to the forum")
	await shot("forum")
	var gnaeus: Node3D = main.get_node("Rome/VenatorGnaeus")
	expect(await walk_to(gnaeus.global_position + Vector3(1.8, 0, 0), 0.6, 30.0), "to the venator")
	player().ask_for_contract(gnaeus)
	await _wait_until(func(): return not me.slayer_task.is_empty(), 15.0)
	expect(me.slayer_task.get("venator", "") == "gnaeus", "a contract from Gnaeus (%s)" % [me.slayer_task])
	var dealer: Node3D = main.get_node("Rome/FaustusTheDealer")
	var wares: Array = WorldMenu.wares_for(player(), dealer).filter(func(o): return o[0].begins_with("Buy bread"))
	expect(wares.size() == 1, "Faustus sells bread")
	if wares.size() == 1:
		var bread: int = me.inventory.count("bread")
		wares[0][1].call()
		await _wait_until(func(): return me.inventory.count("bread") > bread, 20.0)
		expect(me.inventory.count("bread") > bread, "bought bread")
	await walk_to(Vector3(-606, 0, 0), 1.0, 30.0)
	await shot("temple")

	var home: Node3D = main.get_node("Rome/ShipToPortus")
	player().travel(home)
	await _wait_until(func(): return player().global_position.x > -400.0, 60.0)
	expect(player().global_position.x > -400.0, "and home again (at %s)" % player().global_position.round())


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
