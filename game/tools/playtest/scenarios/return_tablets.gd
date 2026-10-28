extends "res://tools/playtest/scenario.gd"
## Return tablets: from beyond the Limes, read one home to the fort; then
## the harbour's from Seriphos. Both land somewhere you can walk from.

const PLAYER := 1


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.max_hp = 500
	me.hp = 500
	driver().sim.give_item(PLAYER, "return_tablet_fort", 1, "test", [])
	driver().sim.give_item(PLAYER, "return_tablet_portus", 1, "test", [])
	for spec in [["return_tablet_fort", Vector3(0, 1, -380), Vector3(2, 0, 3)], ["return_tablet_portus", Vector3(-300, 1, 290), Vector3(-300, 0, -8)]]:
		player().destination = null
		player().global_position = spec[1]
		await seconds(1.0)
		driver().sim.queue_item_action(PLAYER, "read", {"slot": _slot_of(spec[0])})
		await seconds(1.0)
		var here := player().global_position
		expect(Vector2(here.x, here.z).distance_to(Vector2(spec[2].x, spec[2].z)) < 1.0, "%s carried you there (%s)" % [spec[0], here])
		var start := player().global_position
		await walk_to(start + Vector3(3, 0, 0), 0.5, 10.0)
		expect(player().global_position.distance_to(start) > 2.0, "and you can walk away from %s" % spec[0])
	await shot("portus")


func _slot_of(item_id: String) -> int:
	var slots: Array = driver().sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1
