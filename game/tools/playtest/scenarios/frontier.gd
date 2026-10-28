extends "res://tools/playtest/scenario.gd"
## Beyond the Limes: the gate warns first, then lets you through; the HUD
## marks the danger zone; gold can be mined by the ridge; and dying out
## there leaves your belongings on the ground, with no grave.

const PLAYER := 1


func run() -> void:
	await seconds(0.5)
	var sim: RefCounted = driver().sim
	var me: RefCounted = sim.get_combatant(PLAYER)
	for skill in ["mining", "defence", "vitality"]:
		me.skills.xp[skill] = me.skills.xp_for_level(60)
	me.max_hp = 60
	me.hp = 60
	sim.give_item(PLAYER, "iron_pickaxe", 1, "test", [])
	for i in 4:
		sim.give_item(PLAYER, "bread", 1, "test", [])

	var gate: Node3D = main.get_node("LimesGate")
	await route_to(Vector3(0, 0, -42), 1.0, 90.0)
	await walk_to(gate.global_position + Vector3(0, 0, 1.6), 0.6, 30.0)
	player().travel(gate)
	await seconds(1.5)
	expect(gate.warned and player().global_position.z > -60.0, "the gate warns before letting you through")
	player().travel(gate)
	await _wait_until(func(): return player().global_position.z < -300.0, 20.0)
	expect(player().global_position.z < -300.0, "crossing again leads beyond the Limes")
	await seconds(1.0)
	var hud: Node = main.get_node("Hud")
	expect(not hud._danger.visible, "the yard inside the palisade is safe")
	await shot("yard")

	await walk_to(Vector3(0, 0, -362), 0.6, 30.0)
	await seconds(1.0)
	expect(hud._danger.visible, "the HUD marks the danger zone")
	expect(main.get_node("Sound").zone == "frontier", "wind and wolves beyond the Limes (%s)" % main.get_node("Sound").zone)
	await shot("beyond")

	# Dire wolves and raiders roam the road; don't let one end the walk early.
	me.max_hp = 500
	me.hp = 500
	me.bonuses["defence"] = 5000
	me.auto_retaliate = false
	for waypoint in [Vector3(0, 0, -372), Vector3(-14, 0, -400), Vector3(-26, 0, -428)]:
		await walk_to(waypoint, 0.8, 60.0)
	var rock: Node3D = main.get_node("Frontier/Gold1")
	driver().sim.queue_stop(PLAYER)
	await seconds(0.3)
	player().mine(rock)
	await _wait_until(func(): return me.inventory.count("gold_ore") > 0, 90.0)
	expect(me.inventory.count("gold_ore") > 0, "mined gold by the ridge")
	await shot("mine")

	# Die out here: everything but the 3 most valuable items stays behind.
	var raiders := get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.monster_id == "germanic_raider")
	var wolves := get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.monster_id == "dire_wolf")
	expect(raiders.size() == 4 and wolves.size() == 4, "raiders and dire wolves roam the frontier")
	var died_at: Vector3 = me.position
	var killer: RefCounted = sim.add_combatant(900)
	killer.bonuses = {"attack": 5000, "strength": 5000, "defence": 0}
	killer.position = me.position + Vector3(1, 0, 0)
	me.bonuses["defence"] = 0
	me.hp = 1
	sim.queue_attack(900, PLAYER)
	await _wait_until(func(): return count_events("death", {"id": PLAYER}) > 0, 20.0)
	expect(count_events("death", {"id": PLAYER}) > 0, "the player died beyond the Limes")
	await seconds(1.0)
	expect(sim.grave_of(PLAYER).is_empty(), "no grave beyond the Limes")
	var piles: Array = sim.ground_piles().filter(func(pile): return pile["position"].distance_to(died_at) < 3.0)
	expect(piles.size() == 1 and piles[0]["items"].any(func(e): return e["item"] == "bread"), "the bread lies where the player fell")
	metric("kept_items", me.inventory.slots.filter(func(slot): return slot != null).size())


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
