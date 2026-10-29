extends "res://tools/playtest/scenario.gd"
## The circus: take the road east from the fort, pay the factio agent, and
## drive three laps round the spina against the Blues and the Greens by
## steering a little ahead along the racing line.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")
const Circus := preload("res://scripts/sim/circus.gd")


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.skills.xp["athletics"] = me.skills.xp_for_level(30)
	driver().sim.give_item(PLAYER, "coins", 100, "test", [])
	var coins_before: int = me.inventory.count("coins")
	player()._arrive_through(main.get_node("RoadToCircus"))
	await seconds(0.5)
	expect(player().global_position.x > 260.0, "the road leads to the circus")
	await shot("arrival")

	var agent: Node3D = main.get_node("Circus/FactioAgent")
	var options: Array = WorldMenu.options_for(player(), agent).filter(func(o): return o[0].begins_with("Race a chariot"))
	expect(options.size() == 1, "the agent offers a race")
	if options.size() == 1:
		options[0][1].call()
	await _wait_until(func(): return Circus.is_racing(me), 40.0)
	expect(Circus.is_racing(me), "entered the race")
	expect(me.inventory.count("coins") == coins_before - Circus.data()["fee"], "paid the entry fee")
	var start := player().global_position
	await seconds(1.0)
	expect(player().global_position.distance_to(start) < 0.5, "held at the line until the cloth drops")

	var track: Dictionary = driver().sim.circus.tracks["castra"]
	var shot_taken := false
	var finished := false
	driver().sim_event.connect(func(e): if e["type"] == "race_finished": metric("place", e["place"]))
	for i in 1200:
		if not Circus.is_racing(me):
			finished = true
			break
		var s := Circus.progress(track, player().global_position)
		player().destination = Circus.point_at(track, s + 8.0)
		if not shot_taken and me.race.get("lap", 0) == 1 and s > 40.0:
			shot_taken = true
			await shot("racing")
		await seconds(0.1)
	expect(finished, "finished the race")
	expect(me.skills.xp["athletics"] > me.skills.xp_for_level(30), "athletics xp")
	expect(player().get_node_or_null("Chariot") == null, "the chariot is returned")


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
