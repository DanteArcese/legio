extends "res://tools/playtest/scenario.gd"
## Tiro, start to finish: read the quest log, enlist with Optio Gaius,
## strike the dummy with blade, sling, and curse, kill three granary rats,
## and report back for the parma, the rank, and the quartermaster's stores.

const PLAYER := 1
const DUMMY := 100


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var quest_ui: Node = main.get_node("QuestUi")
	var optio: Node3D = main.get_node("OptioGaius")

	await seconds(0.7)
	expect(quest_ui.marker_text(optio) == "!", "a \"!\" over the optio for a new recruit")
	await shot("marker")
	await press("quest_log")
	expect(quest_ui.is_log_open(), "J opens the quest log")
	expect("Speak to Optio Gaius" in quest_ui.log_text(), "the log says who to talk to")
	await shot("quest_log")
	await press("quest_log")

	player().talk(optio)
	await _wait_until(func(): return quest_ui.is_dialogue_open(), 20.0)
	expect(quest_ui.is_dialogue_open(), "talking opens the dialogue box")
	await shot("dialogue")
	for i in 10:
		if not quest_ui.is_dialogue_open():
			break
		await press("interact")
	expect(not quest_ui.is_dialogue_open(), "Interact pages through to the end")
	expect(me.inventory.count("sling") == 1 and me.inventory.count("lituus") == 1, "the optio handed out a sling and a lituus")
	await seconds(0.7)
	expect(quest_ui.marker_text(optio) == "", "no marker while the quest is under way")

	for style in [["bronze_pugio", ""], ["sling", "lead_glans"], ["lituus", "binding_tablet"]]:
		var step: int = me.quests["tiro"]["step"]
		await _wield(style[0], style[1])
		player().attack(DUMMY)
		await _wait_until(func(): return me.quests["tiro"]["step"] > step, 60.0)
		expect(me.quests["tiro"]["step"] > step, "the %s step is done" % style[0])
		driver().sim.queue_stop(PLAYER)
		await seconds(0.7)

	await _wield("bronze_pugio", "")
	for attempt in 12:
		if me.quests["tiro"]["step"] >= 4:
			break
		var rat := _nearest_rat()
		if rat == null:
			await seconds(3.0)
			continue
		player().attack(rat.entity_id)
		await _wait_until(func(): return not rat.combatant.is_alive(), 30.0)
		await seconds(0.7)
	expect(me.quests["tiro"]["step"] == 4, "three rats killed")
	await seconds(0.7)
	expect(quest_ui.marker_text(optio) == "?", "a \"?\" when it's time to report")

	player().talk(optio)
	await _wait_until(func(): return quest_ui.is_dialogue_open(), 30.0)
	await shot("hand_in")
	for i in 10:
		if not quest_ui.is_dialogue_open():
			break
		await press("interact")
	expect(me.quests["tiro"]["done"], "Tiro complete")
	expect(me.inventory.count("parma") == 1, "rewarded a parma")
	var options: Array = WorldMenu.options_for(player(), optio).map(func(o): return o[0])
	expect(options.any(func(label): return label.begins_with("Buy iron gladius")), "the quartermaster's stores are open (%s)" % [options])
	await press("quest_log")
	expect("complete" in quest_ui.log_text(), "the log shows Tiro complete")
	await shot("quest_complete")


const WorldMenu := preload("res://scripts/player/world_menu.gd")


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
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for i in me.inventory.size:
		var slot: Variant = me.inventory.slots[i]
		if slot and slot["item"] == item_id:
			return i
	return -1


func _nearest_rat() -> Node:
	var best: Node = null
	var best_distance := INF
	for entity in get_tree().get_nodes_in_group("sim_entities"):
		if entity.monster_id != "rat" or not entity.combatant.is_alive():
			continue
		var distance := player().global_position.distance_to(entity.body().global_position)
		if distance < best_distance:
			best = entity
			best_distance = distance
	return best


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
