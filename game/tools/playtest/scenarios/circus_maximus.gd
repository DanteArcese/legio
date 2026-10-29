extends "res://tools/playtest/scenario.gd"
## The Circus Maximus in Rome: the Reds' agent enters a citizen with
## Athletics 50 in a four-lap race; the player drives a quadriga against four
## rival factions on the Roman track, and can pull up and leave.

const PLAYER := 1
const Skills := preload("res://scripts/sim/skills.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.skills.xp["athletics"] = Skills.xp_for_level(55)
	driver().sim.give_item(PLAYER, "coins", 1000, "test", [])
	var agent: Node3D = main.get_node("Rome/MaximusAgent")
	player().destination = null
	player().global_position = agent.global_position + Vector3(1.5, 0, 0)
	await seconds(1.0)
	player().start_race(agent)
	await seconds(1.5)
	expect(me.race.get("circus", "") == "maximus", "entered at the Maximus (%s)" % [me.race])
	var rivals: Node = main.get_node("RaceRivals")
	expect(rivals.get_child_count() == 4, "four rival chariots (%d)" % rivals.get_child_count())
	var horses := 0
	for node in player().find_children("*", "MeshInstance3D", true, false):
		if node.get_parent().name == "Chariot":
			horses += 1
	metric("chariot_parts", horses)
	await seconds(4.0)
	await shot("start")
	set_stick(Vector2(0, -1))
	await seconds(5.0)
	set_stick(Vector2.ZERO)
	await shot("racing")
	expect(me.race.has("start"), "still racing")
	driver().sim.queue_item_action(PLAYER, "leave_race")
	await seconds(1.0)
	expect(me.race.is_empty(), "pulled up and left")
	expect(rivals.get_child_count() == 0 or rivals.get_children().all(func(c): return c.is_queued_for_deletion()), "rivals gone")
