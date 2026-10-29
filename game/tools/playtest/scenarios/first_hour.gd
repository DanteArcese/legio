extends "res://tools/playtest/scenario.gd"
## A fresh character's first quests, the way the quest markers lead them:
## Tiro with Optio Gaius, Gifts for the Gods (bones and a goat hide), and a
## look at what Aulus would assign. (The Smith's Apprentice is
## smiths_apprentice.gd, which reuses these helpers.)
## Reports minutes, deaths and the lowest HP for each stage; a death is a
## failure, since none of this should be dangerous to someone who eats.

const PLAYER := 1
const DUMMY := 100
const Slayer := preload("res://scripts/sim/slayer.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")
## Eat (or rest, with no food) at this many hitpoints.
const HURT := 4

var _start := 0
var _lowest_hp := 99


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	expect(me.combat_level() <= 3, "a fresh character (combat %d)" % me.combat_level())

	_begin()
	await _tiro(me)
	_end("tiro")
	metric("combat_after_tiro", me.combat_level())

	_begin()
	await _talk(main.get_node("Sacerdos"))
	expect(me.quests.has("gifts_for_the_gods"), "the sacerdos asks for gifts")
	await _hunt(me, "goat", func(): return me.inventory.count("bones") >= 5 and me.inventory.count("goat_hide") >= 1, 30, ["bones", "goat_hide"])
	await route_to(main.get_node("Sacerdos").global_position + Vector3(1.5, 0, 0), 1.0)
	await _talk(main.get_node("Sacerdos"))
	expect(me.quests.get("gifts_for_the_gods", {}).get("done", false), "Gifts for the Gods done")
	_end("gifts")

	# What Aulus would hand this character now: nothing that kills them.
	var tasks: Array = Slayer.eligible_tasks(ContentDB.venator("aulus"), me.combat_level(), me.skills.level("slayer"))
	var monsters := tasks.map(func(t): return t["monster"])
	metric("aulus_would_assign", monsters)
	expect(monsters.all(func(m): return m in ["rat", "goat"]), "Aulus only assigns rats and goats at combat %d (%s)" % [me.combat_level(), monsters])

	metric("deaths", count_events("death", {"id": PLAYER}))
	metric("combat_after_hour", me.combat_level())
	expect(count_events("death", {"id": PLAYER}) == 0, "no deaths in the first hour")
	await shot("after_an_hour")


func _begin() -> void:
	_start = driver().sim.tick
	_lowest_hp = driver().sim.get_combatant(PLAYER).hp


func _end(stage: String) -> void:
	print("[first_hour] %s done after %.1f min, lowest hp %d" % [stage, (driver().sim.tick - _start) * 0.6 / 60.0, _lowest_hp])
	metric("%s_minutes" % stage, snappedf((driver().sim.tick - _start) * 0.6 / 60.0, 0.1))
	metric("%s_lowest_hp" % stage, _lowest_hp)


func _tiro(me: RefCounted) -> void:
	var optio: Node3D = main.get_node("OptioGaius")
	await _talk(optio)
	for style in [["bronze_pugio", ""], ["sling", "lead_glans"], ["lituus", "binding_tablet"]]:
		var step: int = me.quests["tiro"]["step"]
		await _wield(style[0], style[1])
		player().attack(DUMMY)
		await _wait_until(func():
			if me.target_id == -1 and driver().sim.get_combatant(DUMMY).is_alive():
				player().attack(DUMMY)
			return me.quests["tiro"]["step"] > step, 60.0)
		driver().sim.queue_stop(PLAYER)
		await seconds(0.7)
	await _wield("bronze_pugio", "")
	await _hunt(me, "rat", func(): return me.quests["tiro"]["step"] >= 4, 12, ["bones"])
	await route_to(optio.global_position + Vector3(1.5, 0, 0), 1.0)
	await _talk(optio)
	expect(me.quests["tiro"].get("done", false), "Tiro done")


## Talks to an NPC and pages through the dialogue.
func _talk(npc: Node3D) -> void:
	var quest_ui: Node = main.get_node("QuestUi")
	player().talk(npc)
	await _wait_until(func(): return quest_ui.is_dialogue_open(), 40.0)
	for i in 12:
		if not quest_ui.is_dialogue_open():
			break
		await press("interact")
	await seconds(0.5)


## Hunts a monster until done() or out of attempts, picking up the wanted
## drops, eating when hurt, and resting when out of food.
func _hunt(me: RefCounted, monster: String, done: Callable, attempts: int, wanted: Array) -> void:
	for attempt in attempts:
		if done.call():
			return
		while me.hp <= HURT and _slot_of("bread") == -1 and me.hp < me.max_hp:
			await seconds(10.0)
		var target := _nearest(monster)
		if target == null:
			await seconds(3.0)
			continue
		if player().global_position.distance_to(target.body().global_position) > 8.0:
			await route_to(target.body().global_position, 4.0, 120.0)
		player().attack(target.entity_id)
		await _wait_until(func():
			_lowest_hp = mini(_lowest_hp, me.hp)
			if me.hp <= HURT and _slot_of("bread") != -1:
				driver().sim.queue_item_action(PLAYER, "eat", {"slot": _slot_of("bread")})
			return not target.combatant.is_alive() or not me.is_alive(), 40.0)
		if not me.is_alive():
			for entity in get_tree().get_nodes_in_group("sim_entities"):
				if entity.combatant.target_id == PLAYER:
					print("[first_hour]   attacked by %s (level %d)" % [entity.monster_id, entity.combatant.display_level])
		await seconds(1.8)
		var pile: Node3D = driver().nearest_pile(player().global_position, 3.0, me.inventory)
		if pile:
			for item in wanted:
				if not pile.items.any(func(e): return e["item"] == item):
					continue
				var had: int = me.inventory.count(item)
				player().take(pile, item)
				await _wait_until(func(): return me.inventory.count(item) > had, 5.0)


func _mine(me: RefCounted, each: int) -> void:
	for i in 80:
		if me.inventory.count("copper_ore") >= each and me.inventory.count("tin_ore") >= each:
			return
		var ore := "copper" if me.inventory.count("copper_ore") < each else "tin"
		var rock := _available_rock(ore + "_rock")
		if rock == null:
			await seconds(1.0)
			continue
		await route_to(rock.global_position + (player().global_position - rock.global_position).normalized() * 1.4, 0.3)
		await press("interact")
		await seconds(0.3)
		while not me.skill_action.is_empty():
			await seconds(0.3)


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


func _nearest(monster: String) -> Node:
	var best: Node = null
	var best_distance := INF
	for entity in get_tree().get_nodes_in_group("sim_entities"):
		if entity.monster_id != monster or not entity.combatant.is_alive():
			continue
		var distance := player().global_position.distance_to(entity.body().global_position)
		if distance < best_distance:
			best = entity
			best_distance = distance
	return best


func _wield(weapon: String, ammo: String) -> void:
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for item_id in [weapon, ammo]:
		if item_id.is_empty() or me.equipment.worn.values().has(item_id):
			continue
		var slot := _slot_of(item_id)
		if slot != -1:
			driver().sim.queue_item_action(PLAYER, "equip", {"slot": slot})
			await seconds(0.7)


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
