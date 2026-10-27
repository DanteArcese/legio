extends "res://tools/playtest/scenario.gd"
## The Silent Gallery: start it with the procurator in Vipasca, hear the
## foreman by the pit, then (fights skipped) hand in the quota and see the
## procurator's new wares.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")
const Quests := preload("res://scripts/sim/quests.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for skill in ["mining", "smithing", "slayer"]:
		me.skills.xp[skill] = me.skills.xp_for_level(45)
	var procurator: Node3D = main.get_node("Vipasca/Procurator")
	player().destination = null
	player().global_position = procurator.global_position + Vector3(1.6, 0, 0)
	await seconds(1.0)
	await press("interact")
	await seconds(1.0)
	expect(Quests.status(me, "the_silent_gallery") == "in_progress", "the procurator gives the quest")
	await shot("procurator")
	await _read_dialogue()

	var foreman: Node3D = main.get_node("Vipasca/ForemanMasculus")
	expect(await route_to(foreman.global_position + Vector3(-1.4, 0, 0), 0.5, 60.0), "walked to the foreman")
	await press("interact")
	await seconds(1.0)
	expect(me.quests["the_silent_gallery"]["step"] == 1, "the foreman explains")
	await shot("foreman")
	await _read_dialogue()

	# The basilisk fights have their own playtest; skip to the quota.
	me.quests["the_silent_gallery"] = {"step": 2, "progress": 0, "done": false}
	driver().sim.give_item(PLAYER, "silver_bar", 5, "test", [])
	player().destination = null
	player().global_position = procurator.global_position + Vector3(1.6, 0, 0)
	await seconds(1.0)
	for i in 2:
		await press("interact")
		await seconds(1.0)
		await _read_dialogue()
	expect(Quests.is_done(me, "the_silent_gallery"), "quest complete")
	var labels := []
	for option in WorldMenu.options_for(player(), procurator):
		labels.append(option[0])
		# Long shop lists fold into a Trade submenu.
		if option[0].begins_with("Trade ("):
			labels.append_array(option[1].get_bound_arguments()[0].map(func(o): return o[0]))
	expect(labels.any(func(w): return w.begins_with("Buy steel pickaxe")), "steel pickaxes for sale now")


func _read_dialogue() -> void:
	var quest_ui: Node = main.get_node("QuestUi")
	for i in 12:
		if not quest_ui.is_dialogue_open():
			return
		await press("interact")
		await seconds(0.3)
