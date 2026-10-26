extends "res://tools/playtest/scenario.gd"
## L opens the Tabularium: pages of notable items, counts for those found,
## and a total. A wolf's pelt is logged when you kill it, with a message;
## Esc closes the panel without opening the pause menu.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var panel: Node = main.get_node("CollectionUi")
	var sim: RefCounted = driver().sim
	var me: RefCounted = sim.get_combatant(PLAYER)
	await press("collection_log")
	expect(panel.is_open(), "L opens the Tabularium")
	expect(panel.total_text().begins_with("Collected 0 of "), "nothing collected yet (%s)" % panel.total_text())
	expect(panel.item_lines()[0] == "Wolf pelt  -", "the first page lists the wolf pelt as missing (%s)" % [panel.item_lines()])
	await press("collection_log")

	# Kill a wolf in the north woods.
	for skill in ["attack", "strength", "defence"]:
		me.skills.xp[skill] = me.skills.xp_for_level(40)
	var wolf: Node = get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.monster_id == "wolf")[0]
	await route_to(wolf.get_parent().global_position, 2.0, 90.0)
	sim.queue_attack(PLAYER, wolf.entity_id)
	for i in 40:
		await seconds(0.6)
		if me.collection.has("wolf_pelt"):
			break
	expect(me.collection.get("wolf_pelt", 0) >= 1, "the wolf pelt is logged")
	expect(count_events("collection_new", {"item": "wolf_pelt"}) == 1, "and announced")

	await press("collection_log")
	await seconds(0.2)
	expect(panel.item_lines()[0].begins_with("Wolf pelt  x"), "the page shows it (%s)" % [panel.item_lines()])
	await press("ui_down")
	expect(panel.item_lines()[0] == "Bronze galea  -", "D-pad down moves to the next page (%s)" % [panel.item_lines()])
	await shot("tabularium")
	await press("ui_cancel")
	await seconds(0.1)
	expect(not panel.is_open(), "Esc closes it")
	expect(not main.get_node("PauseMenu").is_open(), "without opening the pause menu")
