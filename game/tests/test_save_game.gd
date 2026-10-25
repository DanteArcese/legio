extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/sim/simulation.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")
const Skills := preload("res://scripts/sim/skills.gd")

const PLAYER := 1


## A player with a bit of everything worth saving.
func _played_sim() -> Simulation:
	var sim := Simulation.new(3)
	var player := sim.add_player(PLAYER, Vector3(2, 0, 3))
	player.account_mode = "solitarius"
	player.skills.xp["attack"] = Skills.xp_for_level(12)
	player.skills.xp["vitality"] = Skills.xp_for_level(14)
	player.max_hp = 14
	player.hp = 9
	player.style = "defensive"
	sim.give_item(PLAYER, "bronze_gladius", 1, "test", [])
	sim.give_item(PLAYER, "coins", 120, "test", [])
	sim.give_item(PLAYER, "bread", 2, "test", [])
	sim.queue_item_action(PLAYER, "equip", {"slot": 0})
	sim.step()
	player.bank.add("copper_ore", 40)
	player.slayer_task = {"monster": "wolf", "remaining": 7, "total": 20, "venator": "aulus"}
	player.slayer_points = 6
	player.slayer_tasks_done = 3
	sim.restore_grave(PLAYER, Vector3(9, 0, 9), [{"item": "bronze_galea", "quantity": 1}], 500)
	sim.reclaimable[PLAYER] = [{"item": "bronze_scutum", "quantity": 1}]
	return sim


func _round_trip(sim: Simulation) -> Simulation:
	var text := SaveGame.to_json(SaveGame.capture(sim, PLAYER))
	var fresh := Simulation.new(3)
	fresh.add_player(PLAYER)
	check(SaveGame.restore(fresh, PLAYER, SaveGame.from_json(text)), "restore succeeded")
	return fresh


func test_round_trip_restores_everything() -> void:
	var original := _played_sim()
	var loaded := _round_trip(original)
	var a: RefCounted = original.get_combatant(PLAYER)
	var b: RefCounted = loaded.get_combatant(PLAYER)
	check_eq(b.account_mode, "solitarius", "account mode")
	check_eq(b.position, Vector3(2, 0, 3), "position")
	check_eq(b.skills.level("attack"), 12, "attack level")
	check_eq(b.max_hp, 14, "max hp from vitality")
	check_eq(b.hp, 9, "hp")
	check_eq(b.style, "defensive", "style")
	check_eq(b.inventory.to_array(), a.inventory.to_array(), "inventory")
	check_eq(b.bank.to_array(), a.bank.to_array(), "bank")
	check_eq(b.equipment.worn["weapon"], "bronze_gladius", "equipment")
	check_eq(b.bonuses, a.bonuses, "bonuses recomputed")
	check_eq(b.slayer_task, a.slayer_task, "slayer task")
	check_eq(b.slayer_points, 6, "points")
	check_eq(b.slayer_tasks_done, 3, "tasks done")
	check_eq(loaded.grave_of(PLAYER)["items"], [{"item": "bronze_galea", "quantity": 1}], "grave items")
	check_eq(loaded.grave_of(PLAYER)["expires_at"], loaded.tick + 500, "grave time left")
	check_eq(loaded.reclaimable[PLAYER], [{"item": "bronze_scutum", "quantity": 1}], "reclaimable")


func test_quantities_come_back_as_ints() -> void:
	var loaded := _round_trip(_played_sim())
	for slot in loaded.get_combatant(PLAYER).inventory.slots:
		if slot:
			check_eq(typeof(slot["quantity"]), TYPE_INT, "%s quantity type" % slot["item"])


func test_loaded_player_keeps_working() -> void:
	var loaded := _round_trip(_played_sim())
	loaded.add_bank(Vector3(2, 0, 3))
	loaded.queue_item_action(PLAYER, "deposit_all")
	loaded.step()
	check_eq(loaded.get_combatant(PLAYER).bank.count("coins"), 120, "can bank loaded coins")


func test_rejects_future_and_garbage_saves() -> void:
	var sim := Simulation.new()
	sim.add_player(PLAYER)
	check(not SaveGame.restore(sim, PLAYER, {"version": SaveGame.VERSION + 1}), "future version")
	check(not SaveGame.restore(sim, PLAYER, {}), "no version")
	check(SaveGame.from_json("not json").is_empty(), "garbage text")
