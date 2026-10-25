extends "res://tools/playtest/scenario.gd"
## Ritual pollution end to end: curse the training dummy inside town (the
## watch warns, then fines), become polluted, get turned away at the
## heavenly altar, wash in the sacred spring, and pray again.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.skills.xp["ritus"] = me.skills.xp_for_level(15)
	driver().sim.give_item(PLAYER, "coins", 100, "test", [])
	for item in [["lituus", 1], ["binding_tablet", 40]]:
		driver().sim.give_item(PLAYER, item[0], item[1], "test", [])
		driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of(item[0])})
		await seconds(0.7)
	# Curse the training dummy, right in the middle of town.
	for i in 9:
		player().attack(100)
		await _wait_until(func(): return count_events("hit", {"attacker": PLAYER, "kind": "ritus"}) > i, 10.0)
	driver().sim.queue_stop(PLAYER)
	expect(count_events("watch_warning", {"id": PLAYER}) == 1, "the watch warned once")
	expect(count_events("watch_fine", {"id": PLAYER}) >= 1, "then fined")
	expect(me.pollution >= 30.0, "polluted (%.0f)" % me.pollution)
	metric("pollution", int(me.pollution))
	metric("coins_left", me.inventory.count("coins"))

	var altar: Node3D = main.get_node("Altars/HeavenlyAltar")
	me.favour = 0.0
	player().pray(altar)
	await seconds(4.0)
	expect(me.favour == 0.0, "the heavenly altar turns the polluted away")

	var spring: Node3D = get_tree().get_first_node_in_group("springs")
	player().wash(spring)
	await _wait_until(func(): return me.pollution == 0.0, 90.0)
	expect(me.pollution == 0.0, "washed clean in the spring")
	await shot("at_the_spring")
	player().pray(altar)
	await _wait_until(func(): return me.favour > 0.0, 90.0)
	expect(me.favour > 0.0, "the altar answers once clean")


func _slot_of(item_id: String) -> int:
	var slots: Array = driver().sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
