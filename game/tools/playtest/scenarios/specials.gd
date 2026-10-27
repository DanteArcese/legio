extends "res://tools/playtest/scenario.gd"
## A special attack on the training dummy: the starting pugio's twin
## thrust, armed with F (B on a controller), shown on the HUD.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	for i in me.inventory.size:
		if me.inventory.slots[i] and me.inventory.slots[i]["item"] == "bronze_pugio":
			driver().sim.queue_item_action(PLAYER, "equip", {"slot": i})
	await seconds(1.0)
	expect(me.equipment.worn["weapon"] == "bronze_pugio", "pugio in hand")
	var hud: Node = main.get_node("Hud")
	expect("Impetus 100" in hud._status.text, "the HUD shows impetus")
	await press("special_attack")
	await seconds(0.7)
	expect(me.special_armed, "F arms the special")
	expect("twin thrust ready" in hud._status.text, "the HUD says it's ready")
	await shot("armed")
	var dummy: Node = get_tree().get_nodes_in_group("sim_entities").filter(func(e): return e.combatant.tag == "training_dummy")[0]
	player().attack(dummy.entity_id)
	for i in 60:
		if count_events("special", {"id": PLAYER}) > 0:
			break
		await seconds(0.25)
	expect(count_events("special", {"id": PLAYER}) == 1, "the twin thrust lands on the dummy")
	expect(me.impetus == 75, "spent 25 (%d left)" % me.impetus)
	expect(main.get_node("Sound").played.get("special", 0) == 1, "with a sound")
	await shot("thrust")
