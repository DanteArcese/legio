extends "res://tests/test_case.gd"
## Loadouts: save what's worn and the style, change back in one action from
## the pack, say what's missing, and keep them in the save.

const Simulation := preload("res://scripts/sim/simulation.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")
const Items := preload("res://scripts/sim/items.gd")
const Skills := preload("res://scripts/sim/skills.gd")

const PLAYER := 1


func _make_sim() -> Simulation:
	var sim := Simulation.new(4)
	var player := sim.add_player(PLAYER)
	for skill in ["attack", "defence", "ranged"]:
		player.skills.xp[skill] = Skills.xp_for_level(30)
	player.inventory.slots.fill(null)
	sim.give_item(PLAYER, "iron_gladius", 1, "test", [])
	sim.give_item(PLAYER, "bronze_scutum", 1, "test", [])
	sim.give_item(PLAYER, "sling", 1, "test", [])
	sim.give_item(PLAYER, "lead_glans", 50, "test", [])
	return sim


func _act(sim: Simulation, action: String, args := {}) -> Array:
	sim.queue_item_action(PLAYER, action, args)
	return sim.step()


func _equip(sim: Simulation, item_id: String) -> void:
	var slots: Array = sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			_act(sim, "equip", {"slot": i})
			return


func test_save_and_wear() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	_equip(sim, "iron_gladius")
	_equip(sim, "bronze_scutum")
	player.style = "aggressive"
	_act(sim, "save_loadout", {"index": 0})
	_equip(sim, "sling")
	_equip(sim, "lead_glans")
	player.style = "rapid"
	_act(sim, "save_loadout", {"index": 1})
	check_eq(Items.loadout_summary(player.loadouts[0]), "Iron gladius and 1 more", "summary")

	var events := _act(sim, "wear_loadout", {"index": 0})
	check_eq(player.equipment.worn["weapon"], "iron_gladius", "the gladius back in hand")
	check_eq(player.equipment.worn["shield"], "bronze_scutum", "and the scutum")
	check_eq(player.style, "aggressive", "and the style")
	check_eq(player.inventory.count("sling"), 1, "the sling went to the pack")
	check(events.any(func(e): return e["type"] == "message" and "change into loadout 1" in e["text"]), "told")

	_act(sim, "wear_loadout", {"index": 1})
	check_eq(player.equipment.worn["weapon"], "sling", "one action to the sling")
	check_eq(player.equipment.worn["ammo"], "lead_glans", "with its lead")
	check_eq(player.style, "rapid", "and rapid fire")


func test_missing_gear_and_empty_slots() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	var events := _act(sim, "wear_loadout", {"index": 2})
	check(events.any(func(e): return e["type"] == "message" and "is empty" in e["text"]), "an empty loadout says so")
	_equip(sim, "iron_gladius")
	_act(sim, "save_loadout", {"index": 2})
	_act(sim, "unequip", {"equip_slot": "weapon"})
	player.inventory.remove("iron_gladius", 1)
	events = _act(sim, "wear_loadout", {"index": 2})
	check(events.any(func(e): return e["type"] == "message" and "Iron gladius" in e["text"]), "names what's missing")


func test_loadouts_are_saved() -> void:
	var sim := _make_sim()
	_equip(sim, "iron_gladius")
	_act(sim, "save_loadout", {"index": 3})
	var text := SaveGame.to_json(SaveGame.capture(sim, PLAYER))
	var fresh := Simulation.new(4)
	fresh.add_player(PLAYER)
	check(SaveGame.restore(fresh, PLAYER, SaveGame.from_json(text)), "restored")
	check_eq(fresh.get_combatant(PLAYER).loadouts[3].get("worn", {}).get("weapon", ""), "iron_gladius", "kept through a save")
	check(fresh.get_combatant(PLAYER).loadouts[0].is_empty(), "the others still empty")
