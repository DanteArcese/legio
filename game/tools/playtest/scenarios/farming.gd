extends "res://tools/playtest/scenario.gd"
## Farming: buy a trowel and mint seeds from the Gaulish merchant, plant a
## herb patch in the fields, let it grow (fast-forwarded, as time away
## would), and harvest it.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	driver().sim.give_item(PLAYER, "coins", 100, "test", [])
	var merchant: Node3D = main.get_node("Forum/Merchant")
	for label in ["Buy trowel", "Buy mint seed"]:
		var option: Array = WorldMenu.wares_for(player(), merchant).filter(func(o): return o[0].begins_with(label))
		expect(option.size() == 1, "the merchant sells: %s" % label)
		if option.size() == 1:
			option[0][1].call()
			await seconds(3.0)
	expect(me.inventory.count("trowel") == 1 and me.inventory.count("mint_seed") == 10, "bought a trowel and mint seeds")

	var patch: Node3D = main.get_node("Farm/HerbPatch1")
	await route_to(Vector3(0, 0, 24), 1.0, 90.0)
	for waypoint in [Vector3(3, 0, 28.5), Vector3(3, 0, 37.5), Vector3(5.8, 0, 39.3)]:
		await walk_to(waypoint, 0.6, 30.0)
	var plant: Array = WorldMenu.options_for(player(), patch).filter(func(o): return o[0] == "Plant mint seed")
	expect(plant.size() == 1, "the empty herb patch offers mint")
	if plant.size() == 1:
		plant[0][1].call()
	await _wait_until(func(): return patch.crop == "mint", 15.0)
	expect(patch.crop == "mint", "mint planted")
	await shot("planted")

	var events := []
	driver().sim.farming.advance(PLAYER, 10000, events)
	for event in events:
		driver().replay_event(event)
	await seconds(0.3)
	expect(patch.grown, "fully grown")
	await shot("grown")
	player().farm(patch)
	await _wait_until(func(): return me.inventory.count("mint") > 0, 15.0)
	expect(me.inventory.count("mint") >= 3, "harvested mint (%d)" % me.inventory.count("mint"))
	expect(patch.crop.is_empty(), "the patch is clear")
	metric("farming_xp", me.skills.xp["farming"])


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
