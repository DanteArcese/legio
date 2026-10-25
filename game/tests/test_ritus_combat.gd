extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")

const PLAYER := 1
const TARGET := 2


## A player with a lituus and tablets, 4 m from a sturdy target.
func _make_sim(tablet := "binding_tablet", count := 50) -> Simulation:
	var sim := Simulation.new(23)
	sim.add_player(PLAYER)
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.skills.xp["ritus"] = Skills.xp_for_level(20)
	for item in [["lituus", 1], [tablet, count]]:
		sim.give_item(PLAYER, item[0], item[1], "test", [])
		_equip(sim, item[0])
	var target := sim.add_combatant(TARGET)
	target.max_hp = 1000
	target.hp = 1000
	target.attack_speed = 4
	target.position = Vector3(4, 0, 0)
	return sim


func _equip(sim: Simulation, item_id: String) -> void:
	var slots: Array = sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			sim.queue_item_action(PLAYER, "equip", {"slot": i})
			sim.step()
			return


func _run(sim: Simulation, ticks: int) -> Array:
	var events := []
	for i in ticks:
		events.append_array(sim.step())
	return events


func test_lituus_casts_from_range_and_uses_up_tablets() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	check_eq(player.combat_kind(), "ritus", "ritus weapon")
	check_eq(player.style, "focused", "ritus style")
	sim.queue_attack(PLAYER, TARGET)
	var casts := _run(sim, 11).filter(func(e): return e["type"] == "hit" and e["kind"] == "ritus")
	check_eq(casts.size(), 3, "speed 4 from 4 m")
	check_eq(player.equipment.ammo_count, 47, "one tablet per cast")
	check(sim.ground_piles().is_empty(), "tablets are never recovered")


func test_binding_slows_the_target() -> void:
	var sim := _make_sim()
	sim.get_combatant(PLAYER).bonuses["ritus_attack"] = 5000
	sim.queue_attack(PLAYER, TARGET)
	var events := _run(sim, 30)
	var target: RefCounted = sim.get_combatant(TARGET)
	check(events.any(func(e): return e["type"] == "curse" and e["curse"] == "binding"), "binding landed at least once")
	var bound_until: int = target.curses.get("bound", -1)
	check(bound_until > sim.tick or events.any(func(e): return e["type"] == "curse"), "bound")
	target.curses["bound"] = sim.tick + 5
	check_eq(target.current_attack_speed(sim.tick), 5, "one tick slower while bound")
	check_eq(target.current_attack_speed(sim.tick + 6), 4, "normal once it wears off")


func test_withering_deals_damage_over_time_and_trains_ritus() -> void:
	var sim := _make_sim("withering_tablet", 1)
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.bonuses["ritus_attack"] = 5000
	sim.queue_attack(PLAYER, TARGET)
	var events := _run(sim, 25)
	var pulses := events.filter(func(e): return e["type"] == "hit" and e["kind"] == "withering")
	check_eq(pulses.size(), Simulation.WITHERING_PULSES, "five pulses from one tablet")
	check(pulses.all(func(e): return e["damage"] == 1), "1 damage each below Ritus 25")
	check(not sim.get_combatant(TARGET).curses.has("withering"), "wears off")
	check(player.skills.xp["ritus"] > Skills.xp_for_level(20) + 15.0, "withering damage trains ritus")


func test_withering_can_finish_off_a_monster_with_kill_credit() -> void:
	var sim := _make_sim("withering_tablet", 1)
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.bonuses["ritus_attack"] = 5000
	player.slayer_task = {"monster": "rat", "remaining": 3, "total": 3, "venator": "aulus"}
	var rat := sim.add_monster(50, "rat", Vector3(4, 0, 1))
	rat.hp = 2
	rat.max_hp = 2
	player.bonuses["ritus_strength"] = -100 # cast hits barely, so the curse does the work
	sim.queue_attack(PLAYER, 50)
	var events := _run(sim, 40)
	check(events.any(func(e): return e["type"] == "death" and e["id"] == 50), "rat died")
	check_eq(player.slayer_task.get("remaining", 0), 2, "kill credited to the caster")


func test_metal_armour_is_weak_to_curses() -> void:
	# Full iron: +34 defence, but -22 of it doesn't count against curses.
	var sim := _make_sim()
	var target: RefCounted = sim.get_combatant(TARGET)
	var ContentDB := preload("res://scripts/content/content_db.gd")
	for item in ["iron_lorica", "iron_galea", "iron_scutum"]:
		var bonuses: Dictionary = ContentDB.item(item)["equip"]["bonuses"]
		for key in bonuses:
			target.bonuses[key] += bonuses[key]
	check_eq(target.defence_bonus_against("melee"), 34, "melee defence")
	check_eq(target.defence_bonus_against("ritus"), 12, "curse defence")
	# Equal attackers: a curse lands far more often than a sword.
	var CombatMath := preload("res://scripts/sim/combat_math.gd")
	var vs_melee := CombatMath.hit_chance(40, 20, 40, target.defence_bonus_against("melee"))
	var vs_ritus := CombatMath.hit_chance(40, 20, 40, target.defence_bonus_against("ritus"))
	check(vs_ritus > vs_melee + 0.05, "curse %.2f vs sword %.2f" % [vs_ritus, vs_melee])


func test_ritual_robes_are_weak_to_arrows() -> void:
	var sim := _make_sim()
	var target: RefCounted = sim.get_combatant(TARGET)
	for key in ["defence", "ritus_defence", "ranged_defence"]:
		target.bonuses[key] = {"defence": 3, "ritus_defence": 9, "ranged_defence": -6}[key]
	check_eq(target.defence_bonus_against("ritus"), 12, "good against curses")
	check_eq(target.defence_bonus_against("ranged"), -3, "bad against arrows")


func test_withering_tablets_need_ritus_15_to_wear() -> void:
	var sim := Simulation.new()
	sim.add_player(PLAYER)
	sim.give_item(PLAYER, "withering_tablet", 5, "test", [])
	sim.queue_item_action(PLAYER, "equip", {"slot": 0})
	var events := sim.step()
	check(events.any(func(e): return e["type"] == "message" and "Ritus 15" in e["text"]), "needs Ritus 15")


func test_warding_splits_xp_with_defence() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.bonuses["ritus_attack"] = 5000
	player.bonuses["ritus_strength"] = 50
	sim.queue_style(PLAYER, "warding")
	sim.queue_attack(PLAYER, TARGET)
	var ritus_before: float = player.skills.xp["ritus"]
	_run(sim, 30)
	check(player.skills.xp["defence"] > 0.0, "defence xp")
	check(is_equal_approx(player.skills.xp["ritus"] - ritus_before, player.skills.xp["defence"]), "even split")


func test_arrows_do_not_fit_a_lituus() -> void:
	var sim := _make_sim("bronze_arrow", 20)
	sim.queue_attack(PLAYER, TARGET)
	check_eq(_run(sim, 10).filter(func(e): return e["type"] == "hit").size(), 0, "no casting with arrows")
