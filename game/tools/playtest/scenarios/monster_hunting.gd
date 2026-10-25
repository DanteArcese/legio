extends "res://tools/playtest/scenario.gd"
## A fresh character equips the starting pugio and works up from rats to
## boars to wolves, cycling combat styles and eating bread when low. Reports
## kill times, damage taken, deaths, food eaten, and drops for each stage,
## to sanity-check early balance.

const PLAYER := 1


func run() -> void:
	driver().sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of("bronze_pugio")})
	await seconds(1.0)
	expect(driver().sim.get_combatant(PLAYER).equipment.worn["weapon"] == "bronze_pugio", "pugio equipped")
	var stages := [["rat", Vector3(13, 0, 9), 12], ["wild_boar", Vector3(0, 0, 33), 8], ["wolf", Vector3(0, 0, -36), 6]]
	var results := {}
	for stage in stages:
		results[stage[0]] = await _hunt(stage[1], stage[0], stage[2])
		await shot(stage[0])
		for key in results[stage[0]]:
			metric("%s_%s" % [stage[0], key], results[stage[0]][key])
	var rats: Dictionary = results["rat"]
	var skills: RefCounted = driver().sim.get_combatant(PLAYER).skills
	metric("combat_level", skills.combat_level())
	metric("levels", "%d/%d/%d/%d" % [skills.level("attack"), skills.level("strength"), skills.level("defence"), skills.level("vitality")])
	metric("player_deaths", count_events("death", {"id": PLAYER}))
	metric("drops", count_events("drop"))
	expect(rats["kills"] >= 12, "should kill 12 rats")
	metric("food_eaten", count_events("ate", {"id": PLAYER}))
	expect(rats["deaths"] == 0, "rats should never kill a player with the starting kit")
	expect(count_events("drop") >= rats["kills"], "every kill with a guaranteed drop should drop")


## Walks to an area and kills monsters of one kind until count kills or a
## time limit. Returns kills, average seconds per kill, damage taken, deaths.
func _hunt(area: Vector3, monster_id: String, count: int) -> Dictionary:
	await route_to(area, 1.0)
	var start_tick: int = driver().sim.tick
	var deaths_before := count_events("death", {"id": PLAYER})
	var taken_before := _damage_taken()
	var kills := 0
	var deadline := start_tick + 2500
	while kills < count and driver().sim.tick < deadline:
		var me: RefCounted = driver().sim.get_combatant(PLAYER)
		if me.target_id == -1:
			var target := _nearest(monster_id)
			if target == -1:
				await seconds(1.0)
				continue
			var where: Vector3 = driver().entity(target).body().global_position
			if player().global_position.distance_to(where) > 6.0:
				await route_to(where, 4.0)
			var styles := ["accurate", "aggressive", "defensive"]
			driver().sim.queue_style(PLAYER, styles[kills % 3])
			driver().sim.queue_attack(PLAYER, target)
			var kills_before := count_events("death", {"id": target})
			while count_events("death", {"id": target}) == kills_before and driver().sim.tick < deadline:
				if not me.is_alive():
					break
				if me.hp <= 4 and _slot_of("bread") != -1:
					driver().sim.queue_item_action(PLAYER, "eat", {"slot": _slot_of("bread")})
				await seconds(0.3)
			if count_events("death", {"id": target}) > kills_before:
				kills += 1
		await seconds(0.3)
	var ticks: int = driver().sim.tick - start_tick
	return {
		"kills": kills,
		"seconds_per_kill": snappedf(ticks * 0.6 / maxi(kills, 1), 0.1),
		"damage_taken": _damage_taken() - taken_before,
		"deaths": count_events("death", {"id": PLAYER}) - deaths_before,
	}


func _nearest(monster_id: String) -> int:
	var best := -1
	var best_distance := INF
	for entity in get_tree().get_nodes_in_group("sim_entities"):
		if entity.monster_id != monster_id or not entity.combatant.is_alive():
			continue
		var distance := player().global_position.distance_to(entity.body().global_position)
		if distance < best_distance:
			best = entity.entity_id
			best_distance = distance
	return best


func _damage_taken() -> int:
	var total := 0
	for event in events:
		if event["type"] == "hit" and event["target"] == PLAYER:
			total += event["damage"]
	return total


func _slot_of(item_id: String) -> int:
	var slots: Array = driver().sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1
