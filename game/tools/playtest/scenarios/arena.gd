extends "res://tools/playtest/scenario.gd"
## Arena contracts: take a boar contract from Lanista Marcia at Portus
## Salis, buy nets, net a weakened boar from its menu, and hand in.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.skills.xp["hunter"] = me.skills.xp_for_level(20)
	driver().sim.give_item(PLAYER, "coins", 100, "test", [])
	var marcia: Node3D = main.get_node("PortusSalis/LanistaMarcia")
	player().destination = null
	player().global_position = marcia.global_position + Vector3(1.6, 0, 0)
	await seconds(1.0)
	await _choose(marcia, "Take: Boars")
	await _wait_until(func(): return not me.arena_contract.is_empty(), 10.0)
	expect(me.arena_contract.get("id") == "boars", "took the boar contract")
	await _choose_ware(marcia, "Buy weighted net")
	await _wait_until(func(): return me.inventory.count("weighted_net") > 0, 10.0)
	expect(me.inventory.count("weighted_net") == 1, "bought a net")
	await shot("marcia")

	var boars := get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.monster_id == "wild_boar")
	var boar: Node = boars[0]
	player().destination = null
	player().global_position = boar.body().global_position + Vector3(2.0, 1, 0)
	await seconds(1.0)
	boar.combatant.hp = 1
	var net: Array = WorldMenu.options_for(player(), boar.body()).filter(func(o): return o[0].begins_with("Throw a net"))
	expect(net.size() == 1, "the boar's menu offers the net")
	if net.size() == 1:
		net[0][1].call()
	await _wait_until(func(): return count_events("captured") > 0, 15.0)
	expect(count_events("captured") == 1, "netted the boar alive")
	expect(me.arena_contract["remaining"] == 4, "four to go")

	me.arena_contract["remaining"] = 0
	player().destination = null
	player().global_position = marcia.global_position + Vector3(1.6, 0, 0)
	await seconds(1.0)
	await _choose(marcia, "Hand in")
	await _wait_until(func(): return me.arena_contract.is_empty(), 10.0)
	expect(count_events("arena_complete") == 1, "Marcia paid")


func _choose(node: Node3D, label: String) -> void:
	var matching: Array = WorldMenu.options_for(player(), node).filter(func(o): return o[0].begins_with(label))
	expect(matching.size() == 1, "menu has '%s'" % label)
	if matching.size() == 1:
		matching[0][1].call()
	await seconds(0.2)


func _choose_ware(node: Node3D, label: String) -> void:
	var matching: Array = WorldMenu.wares_for(player(), node).filter(func(o): return o[0].begins_with(label))
	expect(matching.size() == 1, "sells '%s'" % label)
	if matching.size() == 1:
		matching[0][1].call()
	await seconds(0.2)


func _wait_until(condition: Callable, timeout: float) -> void:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await seconds(0.25)
		waited += 0.25
