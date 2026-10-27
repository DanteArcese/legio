extends "res://tools/playtest/scenario.gd"
## First-time hints: the controls tip on starting, the special-attack tip
## on the first blow with a weapon that has one, each shown only once.

const PLAYER := 1


func run() -> void:
	var hints: Node = main.get_node("Hints")
	await seconds(3.5)
	expect(hints.is_showing() and "pause menu" in hints.shown_text(), "the controls tip on starting")
	await shot("controls_tip")
	await seconds(10.0)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for i in me.inventory.size:
		if me.inventory.slots[i] and me.inventory.slots[i]["item"] == "bronze_pugio":
			driver().sim.queue_item_action(PLAYER, "equip", {"slot": i})
	await seconds(1.0)
	var dummy: Node = get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.combatant.tag == "training_dummy")[0]
	player().attack(dummy.entity_id)
	for i in 60:
		if hints.is_showing():
			break
		await seconds(0.25)
	expect(hints.is_showing() and "special attack" in hints.shown_text(), "the special tip on the first blow")
	expect(hints.seen.has("special"), "remembered")
	hints.hint("special")
	expect(hints._queue.is_empty(), "not shown twice")
