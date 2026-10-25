extends "res://tools/playtest/scenario.gd"
## The bronze loop with the starting kit: mine copper and tin at the quarry,
## smelt bars at the furnace (chosen from the station menu with the
## controller), smith pugios at the anvil, and cook meat at the range.
## Reports XP and time for each stage.

const PLAYER := 1


func run() -> void:
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var start: int = driver().sim.tick
	var target_each := 6
	var deadline := start + 3000
	while (me.inventory.count("copper_ore") < target_each or me.inventory.count("tin_ore") < target_each) \
			and driver().sim.tick < deadline:
		var ore := "copper" if me.inventory.count("copper_ore") < target_each else "tin"
		var rock := _available_rock(ore + "_rock")
		if rock == null:
			await seconds(1.0)
			continue
		await walk_to(rock.global_position + (player().global_position - rock.global_position).normalized() * 1.4, 0.3)
		await press("interact")
		await seconds(0.3)
		while not me.skill_action.is_empty():
			await seconds(0.3)
	metric("mining_minutes", snappedf((driver().sim.tick - start) * 0.6 / 60.0, 0.1))
	metric("mining_level", me.skills.level("mining"))
	expect(me.inventory.count("copper_ore") >= target_each and me.inventory.count("tin_ore") >= target_each, "mined %d of each ore" % target_each)
	await shot("quarry")

	# Smelt via the real station menu: interact, then A on the first entry.
	var ui: Node = main.get_node("GameUi")
	await walk_to(main.get_node("Smithy/Furnace").global_position + Vector3(0, 0, 1.5), 0.3)
	await press("interact")
	await seconds(0.2)
	expect(ui.is_menu_open(), "furnace opens the recipe menu")
	await shot("furnace_menu")
	await press("ui_accept")
	await seconds(0.5)
	while not me.skill_action.is_empty():
		await seconds(0.5)
	expect(me.inventory.count("bronze_bar") == target_each, "smelted %d bronze bars" % target_each)

	await walk_to(main.get_node("Smithy/Anvil").global_position + Vector3(0, 0, 1.5), 0.3)
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "smith", "recipe": "bronze_pugio", "count": 28})
	await seconds(0.5)
	while not me.skill_action.is_empty():
		await seconds(0.5)
	expect(me.inventory.count("bronze_pugio") >= target_each, "smithed pugios")

	driver().sim.give_item(PLAYER, "raw_meat", 10, "test", [])
	await walk_to(main.get_node("Smithy/Range").global_position + Vector3(0, 0, 1.5), 0.3)
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "cook", "recipe": "cooked_meat", "count": 28})
	await seconds(0.5)
	while not me.skill_action.is_empty():
		await seconds(0.5)
	await shot("cooking")
	metric("cooked", me.inventory.count("cooked_meat"))
	metric("burnt", me.inventory.count("burnt_food"))
	metric("smithing_level", me.skills.level("smithing"))
	metric("cooking_level", me.skills.level("cooking"))
	metric("total_minutes", snappedf((driver().sim.tick - start) * 0.6 / 60.0, 0.1))
	expect(me.inventory.count("cooked_meat") + me.inventory.count("burnt_food") == 10, "cooked all the meat")


func _available_rock(rock_type: String) -> Node3D:
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
