extends "res://tools/playtest/scenario.gd"
## The munera: enter from the editor at the circus, fight the first wave
## on the east sands, clear the second by fiat, then fall and be carried
## out with no grave.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")
const Games := preload("res://scripts/sim/games.gd")


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for skill in ["attack", "strength", "defence", "vitality"]:
		me.skills.xp[skill] = me.skills.xp_for_level(60)
	me.max_hp = 60
	me.hp = 60
	driver().sim.give_item(PLAYER, "steel_gladius", 1, "test", [])
	driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of("steel_gladius")})
	var editor: Node3D = main.get_node("Circus/Editor")
	player().destination = null
	player().global_position = editor.global_position + Vector3(0, 0, 1.5)
	await seconds(1.0)
	var options: Array = WorldMenu.options_for(player(), editor).filter(func(o): return o[0].begins_with("Fight in the munera"))
	expect(options.size() == 1, "the editor offers the games")
	if options.size() == 1:
		options[0][1].call()
	await _wait_until(func(): return Games.in_games(me), 20.0)
	expect(Games.in_games(me), "entered the games")
	expect(player().global_position.distance_to(driver().sim.games.arena_center) < 2.0, "out on the sand")
	await _wait_until(func(): return not me.games.get("alive", []).is_empty(), 20.0)
	var first: Array = me.games["alive"].duplicate()
	expect(first.size() == 2, "the first wave is out (%d)" % first.size())
	expect(first.all(func(id): return driver().entity(id) != null), "with bodies in the world")
	await seconds(1.5)
	await shot("wave_one")
	# Fight the first wave for real.
	player().attack(first[0])
	await _wait_until(func(): return me.games.get("wave", 0) >= 2 or not Games.in_games(me), 90.0)
	expect(me.games.get("wave", 0) >= 2, "won the first wave by fighting")
	expect(first.all(func(id): return driver().entity(id) == null), "the first wave's bodies taken away")

	await _wait_until(func(): return not me.games.get("alive", []).is_empty(), 20.0)
	me.hp = 0
	var events: Array[Dictionary] = []
	driver().sim.kill(me, events)
	for event in events:
		driver().replay_event(event)
	await seconds(1.0)
	expect(not Games.in_games(me), "a fall ends the games")
	expect(me.is_alive() and driver().sim.grave_of(PLAYER).is_empty(), "carried out alive, no grave")
	expect(player().global_position.distance_to(editor.global_position) < 4.0, "back by the editor")


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
