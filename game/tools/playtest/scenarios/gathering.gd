extends "res://tools/playtest/scenario.gd"
## A new player chops a tree in the west grove, whittles the log into arrow
## shafts, nets sardines at the pond, and cooks them on the campfire.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for item in ["bronze_axe", "small_net", "knife"]:
		if me.inventory.count(item) == 0:
			driver().sim.give_item(PLAYER, item, 1, "test", [])

	# The grove is west of the fort, which has no west gate: round the south-west corner.
	await route_to(Vector3(-24, 0, 24), 1.0, 120.0)
	var tree := _nearest("trees", func(node): return node.tree_type == "tree")
	await route_to(tree.global_position + (player().global_position - tree.global_position).normalized() * 1.3, 0.4, 120.0)
	player().chop(tree)
	await _wait_until(func(): return me.inventory.count("logs") >= 1, 40.0)
	expect(me.inventory.count("logs") >= 1, "chopped a log")
	await seconds(0.8)
	expect(tree.felled, "the common tree fell, leaving a stump")
	await shot("stump")

	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "fletch", "recipe": "arrow_shaft", "count": 1})
	await _wait_until(func(): return me.inventory.count("arrow_shaft") >= 15, 10.0)
	expect(me.inventory.count("arrow_shaft") == 15, "whittled 15 arrow shafts anywhere")

	var spot := _nearest("fishing_spots", func(node): return node.spot_type == "net_spot")
	# Along the road, clear of the field fences and the campfire.
	for waypoint in [Vector3(-24, 0, 24.5), Vector3(13, 0, 25), Vector3(18, 0, 27)]:
		await walk_to(waypoint, 1.0, 60.0)
	await walk_to(Vector3(16.6, 0, 34.4), 0.6, 30.0)
	player().fish(spot)
	await _wait_until(func(): return me.inventory.count("raw_sardine") >= 2, 60.0)
	expect(me.inventory.count("raw_sardine") >= 2, "netted sardines (%d)" % me.inventory.count("raw_sardine"))
	await shot("fishing")
	metric("sardines", me.inventory.count("raw_sardine"))

	var fire := _nearest("stations", func(node): return node.kind == "fire")
	await route_to(fire.global_position + Vector3(1.4, 0, 0), 0.4, 60.0)
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "cook", "recipe": "cooked_sardine", "count": 28})
	await _wait_until(func(): return me.inventory.count("raw_sardine") == 0, 60.0)
	var cooked: int = me.inventory.count("cooked_sardine") + me.inventory.count("burnt_food")
	expect(cooked >= 2, "cooked the catch on the campfire (%d)" % cooked)
	await shot("campfire")
	metric("woodcutting_xp", me.skills.xp["woodcutting"])
	metric("fishing_xp", me.skills.xp["fishing"])


func _nearest(group: String, accept: Callable) -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(group):
		if not accept.call(node):
			continue
		var distance := player().global_position.distance_to(node.global_position)
		if distance < best_distance:
			best = node
			best_distance = distance
	return best


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
