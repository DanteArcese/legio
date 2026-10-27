extends "res://tests/test_case.gd"
## Weapon specials: Impetus, arming, and what each special does.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Combat := preload("res://scripts/sim/combat.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")

const PLAYER := 1
const DUMMY := 100


func _make_sim(weapon: String) -> Simulation:
	var sim := Simulation.new(14)
	var player := sim.add_player(PLAYER)
	player.equipment.worn["weapon"] = weapon
	player.apply_equipment()
	var dummy := sim.add_combatant(DUMMY)
	dummy.max_hp = 10000
	dummy.hp = 10000
	dummy.can_fight = false
	dummy.auto_retaliate = false
	dummy.position = Vector3(1, 0, 0)
	return sim


func _arm_and_swing(sim: Simulation) -> Array:
	sim.queue_item_action(PLAYER, "special")
	sim.step()
	sim.queue_attack(PLAYER, DUMMY)
	var events := []
	for i in 4:
		events.append_array(sim.step())
	return events


func test_a_twin_thrust_strikes_twice_for_25_impetus() -> void:
	var sim := _make_sim("bronze_pugio")
	var player: RefCounted = sim.get_combatant(PLAYER)
	var events := _arm_and_swing(sim)
	var first_tick: int = events.filter(func(e): return e["type"] == "special")[0]["tick"]
	var hits := events.filter(func(e): return e["type"] == "hit" and e["attacker"] == PLAYER and e["tick"] == first_tick)
	check_eq(hits.size(), 2, "two hits in one attack")
	check_eq(player.impetus, 75, "25 spent")
	check(not player.special_armed, "disarmed after use")
	check(events.any(func(e): return e["type"] == "special" and e["name"] == "twin thrust"), "special event")


func test_not_enough_impetus_means_a_plain_attack() -> void:
	var sim := _make_sim("bronze_gladius")
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.impetus = 30
	var events := _arm_and_swing(sim)
	check_eq(player.impetus, 30, "nothing spent")
	check(not events.any(func(e): return e["type"] == "special"), "no special")
	check(events.any(func(e): return e["type"] == "message" and "need 50 impetus" in e["text"]), "told why")


func test_no_special_without_a_weapon_that_has_one() -> void:
	var sim := _make_sim("")
	var events := []
	sim.queue_item_action(PLAYER, "special")
	events.append_array(sim.step())
	check(not sim.get_combatant(PLAYER).special_armed, "not armed")
	check(events.any(func(e): return e["type"] == "message" and "no special" in e["text"]), "told why")


func test_impetus_refills_over_time() -> void:
	var sim := _make_sim("bronze_pugio")
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.impetus = 0
	for i in Simulation.REGEN_INTERVAL * 5:
		sim.step()
	check_eq(player.impetus, 100, "full after five minutes")


func test_specials_change_accuracy_and_damage() -> void:
	var strong: Dictionary = Combat.SPECIAL_EFFECTS["strong"]
	check(strong["accuracy"] > 1.0 and strong["damage"] > 1.0, "legion's thrust")
	check(Combat.SPECIAL_EFFECTS["heavy"]["damage"] > strong["damage"], "the sweep hits hardest")


func test_impetus_is_saved() -> void:
	var sim := _make_sim("bronze_pugio")
	sim.get_combatant(PLAYER).impetus = 40
	var text := SaveGame.to_json(SaveGame.capture(sim, PLAYER))
	var loaded := _make_sim("bronze_pugio")
	SaveGame.restore(loaded, PLAYER, SaveGame.from_json(text))
	check_eq(loaded.get_combatant(PLAYER).impetus, 40, "kept")
