extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")

const PLAYER := 1


func _make_sim() -> Simulation:
	var sim := Simulation.new(2)
	sim.add_player(PLAYER)
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _slot_of(sim: Simulation, item_id: String) -> int:
	var slots: Array = _player(sim).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1


func _act(sim: Simulation, action: String, args := {}) -> Array:
	sim.queue_item_action(PLAYER, action, args)
	return sim.step()


func test_starting_kit_comes_from_content() -> void:
	var sim := _make_sim()
	sim.give_starting_kit(PLAYER)
	var inv: RefCounted = _player(sim).inventory
	check_eq(inv.count("bronze_pugio"), 1, "pugio")
	check_eq(inv.count("bread"), 4, "bread")
	check_eq(inv.count("coins"), 25, "coins")


func test_equipping_a_weapon_changes_bonuses_and_speed() -> void:
	var sim := _make_sim()
	sim.give_item(PLAYER, "bronze_pugio", 1, "test", [])
	_act(sim, "equip", {"slot": _slot_of(sim, "bronze_pugio")})
	var player: RefCounted = _player(sim)
	check_eq(player.equipment.worn["weapon"], "bronze_pugio", "worn")
	check_eq(player.inventory.count("bronze_pugio"), 0, "left inventory")
	check_eq(player.bonuses["strength"], 3, "strength bonus")
	check_eq(player.attack_speed, 3, "pugio speed")


func test_equipping_swaps_with_the_worn_item() -> void:
	var sim := _make_sim()
	sim.give_item(PLAYER, "bronze_pugio", 1, "test", [])
	sim.give_item(PLAYER, "bronze_gladius", 1, "test", [])
	_act(sim, "equip", {"slot": _slot_of(sim, "bronze_pugio")})
	_act(sim, "equip", {"slot": _slot_of(sim, "bronze_gladius")})
	check_eq(_player(sim).equipment.worn["weapon"], "bronze_gladius", "gladius worn")
	check_eq(_player(sim).inventory.count("bronze_pugio"), 1, "pugio back in inventory")


func test_requirements_block_equipping() -> void:
	var sim := _make_sim()
	sim.give_item(PLAYER, "iron_gladius", 1, "test", [])
	var events := _act(sim, "equip", {"slot": _slot_of(sim, "iron_gladius")})
	check_eq(_player(sim).equipment.worn["weapon"], "", "not worn")
	check(events.any(func(e): return e["type"] == "message" and "Attack 10" in e["text"]), "message")
	_player(sim).skills.xp["attack"] = Skills.xp_for_level(10)
	_act(sim, "equip", {"slot": _slot_of(sim, "iron_gladius")})
	check_eq(_player(sim).equipment.worn["weapon"], "iron_gladius", "worn at 10")


func test_unequip_needs_space() -> void:
	var sim := _make_sim()
	sim.give_item(PLAYER, "bronze_galea", 1, "test", [])
	_act(sim, "equip", {"slot": 0})
	sim.give_item(PLAYER, "copper_ore", 28, "test", [])
	_act(sim, "unequip", {"equip_slot": "head"})
	check_eq(_player(sim).equipment.worn["head"], "bronze_galea", "still worn")
	_player(sim).inventory.remove("copper_ore", 1)
	_act(sim, "unequip", {"equip_slot": "head"})
	check_eq(_player(sim).equipment.worn["head"], "", "removed")
	check_eq(_player(sim).bonuses["defence"], 0, "bonus gone")


func test_eating_heals_consumes_and_delays_attack() -> void:
	var sim := _make_sim()
	sim.give_item(PLAYER, "bread", 2, "test", [])
	var player: RefCounted = _player(sim)
	player.hp = 3
	var events := _act(sim, "eat", {"slot": _slot_of(sim, "bread")})
	check_eq(player.hp, 8, "healed 5")
	check_eq(player.inventory.count("bread"), 1, "one eaten")
	check_eq(player.next_attack_tick, sim.tick + Simulation.EAT_DELAY, "attack delayed")
	check(events.any(func(e): return e["type"] == "ate" and e["healed"] == 5), "ate event")
	_act(sim, "eat", {"slot": _slot_of(sim, "bread")})
	check_eq(player.hp, player.max_hp, "never above max")


func test_full_inventory_overflow_lands_on_the_ground() -> void:
	var sim := _make_sim()
	var events := []
	sim.give_item(PLAYER, "copper_ore", 30, "test", events)
	check_eq(_player(sim).inventory.count("copper_ore"), 28, "28 carried")
	var piles := sim.ground_piles()
	check_eq(piles.size(), 1, "one pile")
	check_eq(piles[0]["items"], [{"item": "copper_ore", "quantity": 2}], "overflow")


func test_drop_and_pick_up() -> void:
	var sim := _make_sim()
	sim.give_item(PLAYER, "bread", 1, "test", [])
	var events := _act(sim, "drop", {"slot": 0})
	var add_event: Dictionary = events.filter(func(e): return e["type"] == "ground_add")[0]
	check(_player(sim).inventory.is_empty(), "dropped")
	_act(sim, "pickup", {"pile": add_event["pile"]})
	check_eq(_player(sim).inventory.count("bread"), 1, "picked up")
	check(sim.ground_piles().is_empty(), "pile gone")


func test_pickup_out_of_range_does_nothing() -> void:
	var sim := _make_sim()
	sim.give_item(PLAYER, "bread", 1, "test", [])
	var add_event: Dictionary = _act(sim, "drop", {"slot": 0}).filter(func(e): return e["type"] == "ground_add")[0]
	sim.set_position(PLAYER, Vector3(10, 0, 0))
	_act(sim, "pickup", {"pile": add_event["pile"]})
	check(_player(sim).inventory.is_empty(), "still on the ground")


func test_ground_items_expire() -> void:
	var sim := _make_sim()
	sim.give_item(PLAYER, "bread", 1, "test", [])
	_act(sim, "drop", {"slot": 0})
	var removed := false
	for i in Simulation.GROUND_LIFETIME:
		removed = removed or sim.step().any(func(e): return e["type"] == "ground_remove")
	check(removed, "expired")
	check(sim.ground_piles().is_empty(), "gone")


func test_bank_requires_being_near_a_bank() -> void:
	var sim := _make_sim()
	sim.give_item(PLAYER, "coins", 50, "test", [])
	var events := _act(sim, "deposit", {"slot": 0})
	check_eq(_player(sim).bank.count("coins"), 0, "not deposited")
	check(events.any(func(e): return e["type"] == "message"), "told why")


func test_deposit_withdraw_and_deposit_all() -> void:
	var sim := _make_sim()
	sim.add_bank(Vector3(1, 0, 0))
	sim.give_item(PLAYER, "coins", 50, "test", [])
	sim.give_item(PLAYER, "copper_ore", 5, "test", [])
	_act(sim, "deposit", {"slot": _slot_of(sim, "copper_ore")})
	var player: RefCounted = _player(sim)
	check_eq(player.bank.count("copper_ore"), 5, "all of that item")
	check_eq(player.inventory.count("copper_ore"), 0, "left inventory")
	_act(sim, "withdraw", {"item": "copper_ore", "quantity": 2})
	check_eq(player.inventory.count("copper_ore"), 2, "withdrew 2")
	check_eq(player.bank.count("copper_ore"), 3, "3 left in bank")
	_act(sim, "deposit_all")
	check(player.inventory.is_empty(), "inventory empty")
	check_eq(player.bank.count("coins"), 50, "coins banked")


func test_monster_kills_leave_ground_piles() -> void:
	var sim := _make_sim()
	var player: RefCounted = _player(sim)
	player.bonuses["attack"] = 500
	var rat := sim.add_monster(50, "rat", Vector3(1, 0, 0))
	rat.hp = 1
	sim.queue_attack(PLAYER, 50)
	for i in 20:
		sim.step()
	check(sim.ground_piles().any(func(p): return p["items"][0]["item"] == "raw_meat"), "raw meat on the ground")


func test_solitarius_refuses_market_items() -> void:
	var sim := _make_sim()
	_player(sim).account_mode = "solitarius"
	var events := []
	check_eq(sim.give_item(PLAYER, "coins", 10, "market", events), 0, "refused")
	check(events.any(func(e): return e["type"] == "message"), "told why")
	check_eq(sim.give_item(PLAYER, "coins", 10, "drop", events), 10, "drops are fine")
