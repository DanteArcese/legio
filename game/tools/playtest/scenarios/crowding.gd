extends "res://tools/playtest/scenario.gd"
## Three wolves set on the player from the same spot spread out around them
## instead of stacking on one another or standing inside the player.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.skills.xp["defence"] = me.skills.xp_for_level(99)
	var wolves := get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.monster_id == "wolf")
	expect(wolves.size() >= 2, "found wolves (%d)" % wolves.size())
	# An open field east of the fields, clear of trees.
	var spot := Vector3(50, 0, 30)
	player().destination = null
	player().global_position = spot + Vector3(3, 1, 0)
	await seconds(0.5)
	for wolf in wolves:
		wolf.body().global_position = spot + Vector3(0, 1.0, 0)
		wolf.combatant.position = spot
		wolf.combatant.spawn_position = spot
		wolf.combatant.target_id = PLAYER
	for i in 12:
		me.hp = me.max_hp
		await seconds(0.5)
	var bodies: Array = wolves.map(func(w): return w.body())
	var closest := INF
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var gap: float = _flat(bodies[i].global_position - bodies[j].global_position) / (0.7)
			closest = minf(closest, gap)
	var nearest_player := INF
	for body in bodies:
		nearest_player = minf(nearest_player, _flat(body.global_position - player().global_position) / 0.7)
	metric("closest_pair", snappedf(closest, 0.01))
	metric("closest_to_player", snappedf(nearest_player, 0.01))
	expect(closest > 0.8, "wolves keep apart (%.2f of their combined radii)" % closest)
	expect(nearest_player > 0.8, "and out of the player (%.2f)" % nearest_player)
	expect(count_events("hit", {"attacker": wolves[0].entity_id}) > 0, "still close enough to bite")
	await shot("crowd")


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
