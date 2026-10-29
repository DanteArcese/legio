extends "res://tools/playtest/scenarios/first_hour.gd"
## The Smith's Apprentice for a fresh character: five copper and five tin for
## Tertius, two bronze bars, then a pugio from the third, with the starting
## kit's pickaxe and hammer. Reports the minutes it takes.


func run() -> void:
	await seconds(0.5)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	_begin()
	var smith: Node3D = main.get_node("Smithy/SmithTertius")
	await _talk(smith)
	expect(me.quests.has("the_smiths_apprentice"), "Tertius takes an apprentice")
	# Five of each for Tertius, then three bars: two to show him, one for the pugio.
	await _mine(me, 8)
	await route_to(smith.global_position + Vector3(0, 0, 1.4), 1.0)
	await _talk(smith)
	await walk_to(main.get_node("Smithy/Furnace").global_position + Vector3(0, 0, 1.5), 0.3)
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "smelt", "recipe": "bronze_bar", "count": 2})
	await action_done()
	await walk_to(smith.global_position + Vector3(0, 0, 1.4), 0.5)
	await _talk(smith)
	expect(me.inventory.count("bronze_bar") == 0 and me.inventory.count("copper_ore") >= 1, "ore left for one more bar")
	await walk_to(main.get_node("Smithy/Furnace").global_position + Vector3(0, 0, 1.5), 0.3)
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "smelt", "recipe": "bronze_bar", "count": 1})
	await action_done()
	await walk_to(main.get_node("Smithy/Anvil").global_position + Vector3(0, 0, 1.5), 0.3)
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "smith", "recipe": "bronze_pugio", "count": 1})
	await action_done()
	await walk_to(smith.global_position + Vector3(0, 0, 1.4), 0.5)
	await _talk(smith)
	expect(me.quests.get("the_smiths_apprentice", {}).get("done", false), "The Smith's Apprentice done")
	_end("smith")

