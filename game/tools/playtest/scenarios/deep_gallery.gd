extends "res://tools/playtest/scenario.gd"
## The deep gallery under Vipasca: shut until The Silent Gallery is done,
## then down the steps into a lit mine tunnel, past the timbers to the
## silver-and-gold alcove and on to the chamber at the end.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var mouth: Node3D = main.get_node("Vipasca/GalleryMouth")
	player().destination = null
	player().global_position = mouth.global_position + Vector3(0, 1, -2.0)
	await seconds(1.0)
	player().travel(mouth)
	await seconds(2.0)
	expect(player().global_position.z < 445.0 and player().global_position.x < 0.0, "shut before the quest")

	me.quests["the_silent_gallery"] = {"step": 4, "progress": 0, "done": true}
	# A warded, sturdy visitor: the tunnel's basilisks shouldn't end the tour.
	driver().sim.give_item(PLAYER, "mirror_shield", 1, "test", [])
	for i in me.inventory.size:
		if me.inventory.slots[i] and me.inventory.slots[i]["item"] == "mirror_shield":
			driver().sim.queue_item_action(PLAYER, "equip", {"slot": i})
	await seconds(0.7)
	me.bonuses["defence"] = 5000
	# Regulus's venom ignores defence; enough health to walk past his chamber.
	me.max_hp = 1000
	me.hp = 1000
	player().travel(mouth)
	await _wait_until(func(): return player().global_position.x > 150.0, 20.0)
	expect(player().global_position.x > 150.0, "down into the gallery")
	await seconds(1.0)
	expect(main.get_node("AreaLighting").underground, "underground lighting")
	await shot("tunnel")
	for waypoint in [Vector3(167, 0, 384), Vector3(177, 0, 394)]:
		expect(await walk_to(waypoint, 1.0, 40.0), "walked the tunnel to %s" % waypoint)
	expect(await walk_to(Vector3(188, 0, 391.5), 1.0, 30.0), "into the alcove")
	await shot("alcove")
	var rocks := get_tree().get_nodes_in_group("rocks").filter(func(r): return r.global_position.x > 150.0)
	expect(rocks.size() == 4, "silver and gold in the alcove (%d)" % rocks.size())
	for waypoint in [Vector3(177, 0, 394), Vector3(180, 0, 409), Vector3(182, 0, 422)]:
		expect(await walk_to(waypoint, 1.0, 40.0), "walked on to %s" % waypoint)
	await shot("chamber")
	expect(me.remedy_boost("attack") == 0, "the mirror shield kept the gaze off")
	var stairs: Node3D = main.get_node("DeepGallery/StairsUp")
	player().travel(stairs)
	await _wait_until(func(): return player().global_position.x < 100.0, 20.0)
	expect(player().global_position.x < 0.0 and player().global_position.z > 400.0, "back up to the pit")


func _wait_until(condition: Callable, timeout: float) -> void:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await seconds(0.25)
		waited += 0.25
