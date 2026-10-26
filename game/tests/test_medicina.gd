extends "res://tests/test_case.gd"
## Medicina: mixing remedies, and their boosts wearing off.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Items := preload("res://scripts/sim/items.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1


func _make_sim(items := {}) -> Simulation:
	var sim := Simulation.new(15)
	sim.add_player(PLAYER)
	for item_id in items:
		sim.give_item(PLAYER, item_id, items[item_id], "test", [])
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _run(sim: Simulation, ticks: int) -> Array:
	var events := []
	for i in ticks:
		events.append_array(sim.step())
	return events


func _slot_of(sim: Simulation, item_id: String) -> int:
	var slots: Array = _player(sim).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1


func test_mixing_a_mint_tonic_anywhere() -> void:
	var sim := _make_sim({"mortar_and_pestle": 1, "mint": 2, "wine": 2})
	sim.queue_item_action(PLAYER, "craft", {"kind": "medicina", "recipe": "mint_tonic", "count": 2})
	_run(sim, 12)
	check_eq(_player(sim).inventory.count("mint_tonic"), 2, "two tonics")
	check_eq(_player(sim).skills.xp["medicina"], 40.0, "medicina xp")


func test_mixing_needs_the_pestle() -> void:
	var sim := _make_sim({"mint": 1, "wine": 1})
	sim.queue_item_action(PLAYER, "craft", {"kind": "medicina", "recipe": "mint_tonic", "count": 1})
	_run(sim, 6)
	check_eq(_player(sim).inventory.count("mint_tonic"), 0, "no pestle, no tonic")


func test_a_tonic_boosts_and_wears_off() -> void:
	var sim := _make_sim({"fennel_draught": 1})
	var player := _player(sim)
	player.skills.xp["strength"] = player.skills.xp_for_level(50)
	var before: int = player.effective_level("strength")
	sim.queue_item_action(PLAYER, "drink", {"slot": _slot_of(sim, "fennel_draught")})
	_run(sim, 1)
	# 2 + 8% of 50 = 6 levels.
	check_eq(player.remedy_boost("strength"), 6, "six levels of strength")
	check_eq(player.effective_level("strength"), before + 6, "effective level raised")
	_run(sim, Items.REMEDY_DECAY_TICKS + 1)
	check_eq(player.remedy_boost("strength"), 5, "a level wears off each minute")
	_run(sim, Items.REMEDY_DECAY_TICKS * 6)
	check_eq(player.remedy_boost("strength"), 0, "gone in the end")
	check(not player.remedy_boosts.has("strength"), "cleared")


func test_poppy_draught_heals() -> void:
	var sim := _make_sim({"poppy_draught": 1})
	var player := _player(sim)
	player.hp = 1
	sim.queue_item_action(PLAYER, "drink", {"slot": _slot_of(sim, "poppy_draught")})
	_run(sim, 1)
	check_eq(player.hp, mini(17, player.max_hp), "healed")


func test_death_clears_boosts() -> void:
	var sim := _make_sim({"mint_tonic": 1})
	sim.queue_item_action(PLAYER, "drink", {"slot": _slot_of(sim, "mint_tonic")})
	_run(sim, 1)
	check(_player(sim).remedy_boost("attack") > 0, "boosted")
	sim.kill(_player(sim), [])
	check_eq(_player(sim).remedy_boost("attack"), 0, "death takes it")
