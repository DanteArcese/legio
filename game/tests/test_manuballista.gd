extends "res://tests/test_case.gd"
## Woodcutting and Fletching past 60: cedars at 70 and old olives at 80, and
## the manuballista, a torsion crossbow that shoots bolts, not arrows.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const TARGET := 70


func _equip(sim: Simulation, item_id: String) -> void:
	var slots: Array = sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			sim.queue_item_action(PLAYER, "equip", {"slot": i})
			sim.step()
			return


func test_chop_a_cedar_and_fletch_a_manuballista() -> void:
	var sim := Simulation.new(3)
	var player := sim.add_player(PLAYER)
	for skill in ["woodcutting", "fletching"]:
		player.skills.xp[skill] = Skills.xp_for_level(75)
	sim.give_item(PLAYER, "orichalcum_axe", 1, "test", [])
	sim.skilling.add_tree(40, "cedar_tree", Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "chop", {"tree": 40})
	for i in 300:
		sim.step()
		if player.inventory.count("cedar_logs") >= 2:
			break
	check(player.inventory.count("cedar_logs") >= 1, "cedar chopped")
	sim.give_item(PLAYER, "cedar_logs", 2, "test", [])
	sim.give_item(PLAYER, "steel_bar", 2, "test", [])
	sim.give_item(PLAYER, "bowstring", 2, "test", [])
	sim.give_item(PLAYER, "knife", 1, "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "fletch", "recipe": "manuballista", "count": 1})
	for i in 20:
		sim.step()
	check_eq(player.inventory.count("manuballista"), 1, "a manuballista")


func test_it_shoots_bolts_only() -> void:
	var sim := Simulation.new(3)
	var player := sim.add_player(PLAYER)
	player.skills.xp["ranged"] = Skills.xp_for_level(70)
	player.inventory.slots.fill(null)
	sim.give_item(PLAYER, "manuballista", 1, "test", [])
	sim.give_item(PLAYER, "steel_arrow", 20, "test", [])
	_equip(sim, "manuballista")
	_equip(sim, "steel_arrow")
	var target := sim.add_combatant(TARGET)
	target.max_hp = 1000
	target.hp = 1000
	target.can_fight = false
	target.position = Vector3(0, 0, 5)
	player.target_id = TARGET
	for i in 12:
		sim.step()
	check_eq(target.hp, 1000, "arrows won't fit a manuballista")
	sim.give_item(PLAYER, "steel_bolt", 20, "test", [])
	_equip(sim, "steel_bolt")
	player.target_id = TARGET
	for i in 30:
		sim.step()
	check(player.equipment.ammo_count < 20, "bolts loosed")
	check(target.hp < 1000, "and they hit")


func test_tiers() -> void:
	check_eq(ContentDB.tree("old_olive_tree")["level"], 80, "old olive at 80")
	check(ContentDB.item("olivewood_manuballista")["equip"]["bonuses"]["ranged_attack"] > ContentDB.item("yew_longbow")["equip"]["bonuses"]["ranged_attack"], "the best ranged weapon")
