extends "res://tools/playtest/scenario.gd"
## Strongboxes: with no pick the lock won't budge; with lockpicks a thief
## cracks the warehouse box at Portus Salis (often after a trap or two),
## then looks over the Vipasca pay chest and Nikias's coffer.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.skills.xp["thieving"] = me.skills.xp_for_level(60)
	me.skills.xp["vitality"] = me.skills.xp_for_level(40)
	me.max_hp = 40
	me.hp = 40
	var box: Node3D = main.get_node("PortusSalis/WarehouseStrongbox")
	player().destination = null
	player().global_position = box.global_position + Vector3(0, 1, 1.6)
	await seconds(1.0)
	_choose(box, "Crack")
	await seconds(2.0)
	expect(not box.empty, "no lockpick, no luck")

	driver().sim.give_item(PLAYER, "lockpick", 10, "test", [])
	var coins_before: int = me.inventory.count("coins")
	for attempt in 8:
		if box.empty:
			break
		_choose(box, "Crack")
		await _wait_until(func(): return box.empty or me.skill_action.is_empty(), 15.0)
		await seconds(1.6)
	expect(box.empty, "cracked the warehouse strongbox")
	expect(me.skills.xp["thieving"] > me.skills.xp_for_level(60), "thieving xp")
	await shot("warehouse")
	metric("lockpicks_left", me.inventory.count("lockpick"))
	metric("coins_gained", me.inventory.count("coins") - coins_before)

	for path in ["Vipasca/PayChest", "Seriphos/NikiasStrongbox"]:
		var other: Node3D = main.get_node(path)
		player().destination = null
		player().global_position = other.global_position + Vector3(0, 1, 1.6)
		await seconds(1.5)
		expect(WorldMenu.options_for(player(), other).any(func(o): return o[0].begins_with("Crack")), "%s can be cracked" % path)
		await shot(path.get_file().to_snake_case())


func _choose(node: Node, prefix: String) -> void:
	var options: Array = WorldMenu.options_for(player(), node).filter(func(o): return o[0].begins_with(prefix))
	expect(options.size() >= 1, "%s offers: %s" % [node.name, prefix])
	if not options.is_empty():
		options[0][1].call()


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
