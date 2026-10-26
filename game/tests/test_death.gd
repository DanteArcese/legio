extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/sim/simulation.gd")
const DeathRules := preload("res://scripts/sim/death_rules.gd")
const Skills := preload("res://scripts/sim/skills.gd")

const PLAYER := 1
const KILLER := 2


func _make_sim() -> Simulation:
	var sim := Simulation.new(9)
	sim.add_player(PLAYER, Vector3(5, 0, 5))
	return sim


func _give(sim: Simulation, items: Dictionary) -> void:
	for item_id in items:
		sim.give_item(PLAYER, item_id, items[item_id], "test", [])


## Kills the player with an overwhelming attacker; returns that tick's events.
func _die(sim: Simulation) -> Array:
	var player: RefCounted = sim.get_combatant(PLAYER)
	if sim.get_combatant(KILLER) == null:
		var killer := sim.add_combatant(KILLER)
		killer.bonuses = {"attack": 5000, "strength": 5000, "defence": 0}
	sim.get_combatant(KILLER).position = player.position + Vector3(1, 0, 0)
	player.hp = 1
	sim.queue_attack(KILLER, PLAYER)
	for i in 20:
		var events := sim.step()
		if events.any(func(e): return e["type"] == "death" and e["id"] == PLAYER):
			return events
	return []


func _respawn(sim: Simulation) -> void:
	for i in Simulation.PLAYER_RESPAWN_TICKS + 1:
		sim.step()


func test_keeps_three_most_valuable_items() -> void:
	var sim := _make_sim()
	# Values: iron lorica 120, iron scutum 90, iron gladius 75, bronze gladius 25, bread 10, coins 1.
	_give(sim, {"iron_lorica": 1, "iron_scutum": 1, "iron_gladius": 1, "bronze_gladius": 1, "bread": 2, "coins": 500})
	_die(sim)
	var inv: RefCounted = sim.get_combatant(PLAYER).inventory
	check_eq(inv.count("iron_lorica") + inv.count("iron_scutum") + inv.count("iron_gladius"), 3, "kept the iron gear")
	check_eq(inv.count("bronze_gladius") + inv.count("bread") + inv.count("coins"), 0, "lost the rest")
	var grave := sim.grave_of(PLAYER)
	check_eq(grave["items"], [{"item": "bronze_gladius", "quantity": 1}, {"item": "bread", "quantity": 2}, {"item": "coins", "quantity": 500}], "grave items")


func test_worn_items_count_and_stay_worn() -> void:
	var sim := _make_sim()
	_give(sim, {"bronze_lorica": 1, "bread": 3})
	sim.queue_item_action(PLAYER, "equip", {"slot": 0})
	sim.step()
	_die(sim)
	var player: RefCounted = sim.get_combatant(PLAYER)
	check_eq(player.equipment.worn["body"], "bronze_lorica", "lorica still worn")
	check_eq(player.bonuses["defence"], 8, "bonuses still apply")
	check_eq(player.inventory.count("bread"), 2, "two bread kept")


func test_a_stack_counts_once_at_unit_value() -> void:
	var split := DeathRules.split(_container_with({"coins": 100000, "bread": 1, "copper_ore": 3}), preload("res://scripts/sim/equipment.gd").new())
	check_eq(split["kept_inventory"], [{"item": "bread", "quantity": 1}, {"item": "copper_ore", "quantity": 1}, {"item": "copper_ore", "quantity": 1}], "bread and ore beat a coin stack")


func test_loot_grave_returns_items() -> void:
	var sim := _make_sim()
	_give(sim, {"iron_lorica": 1, "iron_scutum": 1, "iron_gladius": 1, "bronze_galea": 1})
	_die(sim)
	_respawn(sim)
	var player: RefCounted = sim.get_combatant(PLAYER)
	check_eq(player.position, Vector3(5, 0, 5), "respawned at spawn")
	player.position = Vector3(50, 0, 50)
	sim.queue_item_action(PLAYER, "loot_grave")
	sim.step()
	check(not sim.grave_of(PLAYER).is_empty(), "too far away")
	player.position = Vector3(5, 0, 5)
	sim.queue_item_action(PLAYER, "loot_grave")
	var events := sim.step()
	check_eq(player.inventory.count("bronze_galea"), 1, "recovered")
	check(sim.grave_of(PLAYER).is_empty(), "grave gone")
	check(events.any(func(e): return e["type"] == "grave_remove"), "grave_remove event")


func test_expired_grave_goes_to_libitinarii_and_reclaim_costs_a_fee() -> void:
	var sim := _make_sim()
	sim.add_libitinarius(Vector3(0, 0, 0))
	_give(sim, {"iron_lorica": 1, "iron_scutum": 1, "iron_gladius": 1, "bronze_lorica": 1})
	_die(sim)
	for i in Simulation.Graves.GRAVE_LIFETIME:
		sim.step()
	check(sim.grave_of(PLAYER).is_empty(), "grave expired")
	check_eq(sim.reclaimable[PLAYER], [{"item": "bronze_lorica", "quantity": 1}], "held by libitinarii")
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.position = Vector3(1, 0, 0)
	sim.queue_item_action(PLAYER, "reclaim")
	var events := sim.step()
	check(events.any(func(e): return e["type"] == "message" and "4 denarii" in e["text"]), "asks for the fee (40 value -> 4)")
	sim.give_item(PLAYER, "coins", 3, "test", [])
	player.bank.add("coins", 10)
	sim.queue_item_action(PLAYER, "reclaim")
	sim.step()
	check_eq(player.bank.count("bronze_lorica"), 1, "returned to the bank")
	check_eq(player.inventory.count("coins"), 0, "inventory coins spent first")
	check_eq(player.bank.count("coins"), 9, "rest from the bank")
	check(not sim.reclaimable.has(PLAYER), "nothing left to reclaim")


func test_dying_again_sends_the_old_grave_to_libitinarii() -> void:
	var sim := _make_sim()
	_give(sim, {"iron_lorica": 1, "iron_scutum": 1, "iron_gladius": 1, "bronze_galea": 1})
	_die(sim)
	_respawn(sim)
	_give(sim, {"bread": 1})
	sim.get_combatant(PLAYER).inventory.add("bronze_pugio", 1)
	_die(sim)
	check_eq(sim.reclaimable[PLAYER], [{"item": "bronze_galea", "quantity": 1}], "first grave went to the libitinarii")


func test_reclaim_fee_is_ten_percent_rounded_up() -> void:
	check_eq(DeathRules.reclaim_fee([{"item": "bronze_gladius", "quantity": 1}]), 3, "25 -> 3")
	check_eq(DeathRules.reclaim_fee([{"item": "coins", "quantity": 1000}]), 100, "coins count too")
	check_eq(DeathRules.reclaim_fee([]), 0, "nothing")


func _container_with(items: Dictionary) -> RefCounted:
	var container: RefCounted = preload("res://scripts/sim/item_container.gd").new(28)
	for item_id in items:
		container.add(item_id, items[item_id])
	return container
