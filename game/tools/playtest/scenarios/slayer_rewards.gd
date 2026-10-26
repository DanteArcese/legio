extends "res://tools/playtest/scenario.gd"
## Slayer rewards at Aulus, through his menu: block the current contract,
## learn the venator's helm, sew it, and wear it.

const PLAYER := 1
const WorldMenu := preload("res://scripts/player/world_menu.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for skill in ["crafting", "ranged", "slayer"]:
		me.skills.xp[skill] = me.skills.xp_for_level(30)
	me.slayer_points = 200
	me.slayer_task = {"monster": "wolf", "remaining": 20, "total": 20, "venator": "aulus"}
	var aulus: Node3D = main.get_node("VenatorAulus")
	var options: Array = WorldMenu.options_for(player(), aulus).map(func(o): return o[0])
	metric("menu", options)
	expect(options.any(func(o): return o.begins_with("Cancel the wolves contract")), "offers a cancel")

	await _choose(aulus, "Never hunt wolves again")
	await _wait_until(func(): return me.slayer_blocked.has("wolf"), 30.0)
	expect(me.slayer_blocked == ["wolf"], "wolves blocked")
	expect(me.slayer_task.is_empty(), "the wolf contract is gone")
	expect(WorldMenu.options_for(player(), aulus).any(func(o): return o[0] == "Hunt wolves again"), "offers to unblock")

	await _choose(aulus, "Learn the venator's helm")
	await _wait_until(func(): return me.slayer_unlocks.has("venators_helm"), 10.0)
	expect(me.slayer_unlocks.has("venators_helm"), "learned the helm")
	metric("points_left", me.slayer_points)

	for entry in [["needle", 1], ["thread", 2], ["leather", 2], ["wolfskin_hood", 1], ["whitethorn_charm", 1]]:
		driver().sim.give_item(PLAYER, entry[0], entry[1], "test", [])
	driver().sim.queue_item_action(PLAYER, "craft", {"kind": "leatherwork", "recipe": "venators_helm", "count": 1})
	await _wait_until(func(): return me.inventory.count("venators_helm") == 1, 20.0)
	expect(me.inventory.count("venators_helm") == 1, "sewed the helm")
	for i in me.inventory.size:
		if me.inventory.slots[i] and me.inventory.slots[i]["item"] == "venators_helm":
			driver().sim.queue_item_action(PLAYER, "equip", {"slot": i})
	await seconds(1.0)
	expect(me.equipment.worn["head"] == "venators_helm", "wearing it")
	await shot("venators_helm")


func _choose(node: Node3D, label: String) -> void:
	var matching: Array = WorldMenu.options_for(player(), node).filter(func(o): return o[0].begins_with(label))
	expect(matching.size() == 1, "menu has '%s'" % label)
	if matching.size() == 1:
		matching[0][1].call()
	await seconds(0.1)


func _wait_until(condition: Callable, timeout: float) -> void:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await seconds(0.25)
		waited += 0.25
