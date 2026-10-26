extends "res://tools/playtest/scenario.gd"
## Thieving in the forum: steal bread from the baker's stall (its goods
## vanish until it restocks), then pick the townsman's pocket until he
## catches you, which roots you to the spot for a moment.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var stall: Node3D = main.get_node("Forum/BakersStall")
	var townsman: Node3D = main.get_node("Forum/Townsman")

	var start_bread: int = me.inventory.count("bread")
	for attempt in 20:
		if me.inventory.count("bread") - start_bread >= 3:
			break
		player().steal(stall)
		await seconds(1.4)
		if stall.empty:
			await shot("stall_empty")
			await _wait_until(func(): return not stall.empty, 15.0)
	expect(me.skills.xp["thieving"] > 0.0, "stealing gives Thieving XP")
	expect(me.inventory.count("bread") - start_bread >= 3, "stole three loaves (%d)" % (me.inventory.count("bread") - start_bread))

	var stunned := false
	var start_coins: int = me.inventory.count("coins")
	for attempt in 40:
		player().pickpocket(townsman)
		await seconds(1.3)
		if me.stunned_until > driver().sim.tick and not stunned:
			stunned = true
			var at := player().global_position
			set_stick(Vector2(1, 0))
			await seconds(1.0)
			set_stick(Vector2.ZERO)
			expect(player().global_position.distance_to(at) < 0.3, "can't walk while stunned")
			await shot("stunned")
			await seconds(3.5)
		if stunned and me.inventory.count("coins") > start_coins:
			break
	expect(stunned, "the townsman caught you eventually")
	expect(me.inventory.count("coins") > start_coins, "picked his pocket at least once")
	metric("coins", me.inventory.count("coins"))
	metric("thieving_xp", me.skills.xp["thieving"])


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
