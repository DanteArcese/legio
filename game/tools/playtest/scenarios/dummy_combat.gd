extends "res://tools/playtest/scenario.gd"
## Player targets the training dummy, walks into reach, and fights it.


func run() -> void:
	await shot("start")
	await press("interact")
	await seconds(3.0)
	await shot("approach")
	var start_tick: int = driver().sim.tick
	await seconds(60.0)
	var ticks: int = driver().sim.tick - start_tick
	await shot("end")

	var hits := count_events("hit", {"attacker": 1})
	var damage := 0
	for event in events:
		if event["type"] == "hit" and event["attacker"] == 1:
			damage += event["damage"]
	metric("ticks", ticks)
	metric("player_hits", hits)
	metric("damage_dealt", damage)
	metric("dummy_kills", count_events("death", {"id": 100}))
	metric("damage_per_tick", snappedf(float(damage) / maxi(ticks, 1), 0.01))
	expect(hits > 10, "player should land repeated attacks (got %d)" % hits)
	expect(count_events("death", {"id": 100}) >= 1, "dummy should die at least once")
	expect(count_events("respawn", {"id": 100}) >= 1, "dummy should respawn")
