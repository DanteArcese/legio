extends "res://tools/playtest/scenario.gd"
## The Ritus supply chain: buy a stylus from the libitinarius, mine galena
## north-west of town, smelt lead sheets, smith bronze nails, and inscribe
## binding tablets at the cemetery tomb using its recipe menu.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.skills.xp["mining"] = me.skills.xp_for_level(10)
	me.skills.xp["smithing"] = me.skills.xp_for_level(5)
	driver().sim.give_item(PLAYER, "coins", 50, "test", [])
	driver().sim.give_item(PLAYER, "bronze_bar", 1, "test", [])
	var start: int = driver().sim.tick

	player().buy(main.get_node("Libitinarius"), "stylus")
	await _wait_until(func(): return me.inventory.count("stylus") == 1, 30.0)
	expect(me.inventory.count("stylus") == 1, "bought a stylus")

	while me.inventory.count("galena") < 2 and driver().sim.tick - start < 3000:
		var rock := _nearest_rock("galena_rock")
		if rock == null:
			await seconds(1.0)
			continue
		await route_to(rock.global_position + (player().global_position - rock.global_position).normalized() * 1.4, 0.4, 90.0)
		player().mine(rock)
		await seconds(1.0)
		while not me.skill_action.is_empty():
			await seconds(0.3)
	expect(me.inventory.count("galena") >= 2, "mined galena")
	await shot("galena")

	await _make_at("Smithy/Furnace", "smelt", "lead_sheet")
	expect(me.inventory.count("lead_sheet") >= 2, "smelted lead sheets")
	await _make_at("Smithy/Anvil", "smith", "bronze_nails")
	expect(me.inventory.count("bronze_nails") == 15, "smithed nails")

	# Inscribe through the tomb's own recipe menu: Use, then A on the first entry.
	var tomb: Node3D = main.get_node("Smithy/Tomb")
	await route_to(tomb.global_position + Vector3(1.6, 0, 0), 0.4, 60.0)
	player().use_station(tomb)
	await seconds(0.3)
	var ui: Node = main.get_node("GameUi")
	expect(ui.is_menu_open() and ui._menu.get_item_text(0).begins_with("Binding tablet"), "tomb offers binding tablets")
	await shot("tomb_menu")
	await press("ui_accept")
	await seconds(0.5)
	while not me.skill_action.is_empty():
		await seconds(0.3)
	metric("binding_tablets", me.inventory.count("binding_tablet"))
	metric("ritus_xp", int(me.skills.xp["ritus"]))
	metric("minutes", snappedf((driver().sim.tick - start) * 0.6 / 60.0, 0.1))
	expect(me.inventory.count("binding_tablet") >= 10, "inscribed binding tablets")


func _make_at(station_path: String, kind: String, recipe: String) -> void:
	var station: Node3D = main.get_node(station_path)
	await route_to(station.global_position + Vector3(0, 0, 1.5), 0.4, 90.0)
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": kind, "recipe": recipe, "count": 28})
	await seconds(0.5)
	while not driver().sim.get_combatant(PLAYER).skill_action.is_empty():
		await seconds(0.3)


func _nearest_rock(rock_type: String) -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for rock in get_tree().get_nodes_in_group("rocks"):
		if rock.rock_type != rock_type or driver().sim.skilling.rocks[rock.rock_id]["depleted_until"] != -1:
			continue
		var distance := player().global_position.distance_to(rock.global_position)
		if distance < best_distance:
			best = rock
			best_distance = distance
	return best


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
