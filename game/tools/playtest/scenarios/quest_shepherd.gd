extends "res://tools/playtest/scenario.gd"
## The Shepherd's Flock: Melissa by the olive grove on Seriphos gives the
## quest; (fights skipped) the cheese is handed in, and Nikias sells it.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")
const Quests := preload("res://scripts/sim/quests.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for skill in ["attack", "strength", "defence"]:
		me.skills.xp[skill] = me.skills.xp_for_level(50)
	var melissa: Node3D = main.get_node("Seriphos/Melissa")
	player().destination = null
	player().global_position = melissa.global_position + Vector3(0, 0, 1.6)
	await seconds(1.0)
	await press("interact")
	await seconds(1.0)
	expect(Quests.status(me, "the_shepherds_flock") == "in_progress", "Melissa gives the quest")
	await shot("melissa")
	await _read_dialogue()
	# The cyclops fights have their own playtest; skip to the cheese.
	me.quests["the_shepherds_flock"] = {"step": 1, "progress": 0, "done": false}
	driver().sim.give_item(PLAYER, "cyclops_cheese", 3, "test", [])
	for i in 2:
		await press("interact")
		await seconds(1.0)
		await _read_dialogue()
	expect(Quests.is_done(me, "the_shepherds_flock"), "quest complete")
	var nikias: Node3D = main.get_node("Seriphos/Nikias")
	expect(WorldMenu.wares_for(player(), nikias).any(func(o): return o[0].begins_with("Buy cyclops cheese")), "Nikias sells the cheese now")


func _read_dialogue() -> void:
	var quest_ui: Node = main.get_node("QuestUi")
	for i in 12:
		if not quest_ui.is_dialogue_open():
			return
		await press("interact")
		await seconds(0.3)
