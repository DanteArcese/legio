extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/sim/simulation.gd")
const Pietas := preload("res://scripts/sim/pietas.gd")
const Skills := preload("res://scripts/sim/skills.gd")

const PLAYER := 1
const TARGET := 2


## A curser with a lituus and plenty of tablets, outside town by default.
func _make_sim(at := Vector3(40, 0, 40)) -> Simulation:
	var sim := Simulation.new(5)
	var player := sim.add_player(PLAYER, at)
	player.skills.xp["ritus"] = Skills.xp_for_level(20)
	player.skills.xp["pietas"] = Skills.xp_for_level(30)
	player.favour = 30.0
	for item in [["lituus", 1], ["binding_tablet", 200], ["coins", 100]]:
		sim.give_item(PLAYER, item[0], item[1], "test", [])
	for item in ["lituus", "binding_tablet"]:
		sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of(sim, item)})
		sim.step()
	var target := sim.add_combatant(TARGET)
	target.max_hp = 100000
	target.hp = 100000
	target.can_fight = false
	target.position = at + Vector3(3, 0, 0)
	return sim


func _slot_of(sim: Simulation, item_id: String) -> int:
	var slots: Array = sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1


func _cast(sim: Simulation, casts: int) -> Array:
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.attack_speed = 1
	sim.queue_attack(PLAYER, TARGET)
	var events := []
	var cast := 0
	while cast < casts:
		var step := sim.step()
		events.append_array(step)
		cast += step.filter(func(e): return e["type"] == "hit" and e["kind"] == "ritus").size()
	sim.queue_stop(PLAYER)
	sim.step()
	return events


func test_curses_build_pollution_that_wears_off() -> void:
	var sim := _make_sim()
	_cast(sim, 5)
	var player: RefCounted = sim.get_combatant(PLAYER)
	check_eq(player.pollution, 5 * Pietas.POLLUTION_PER_CURSE, "4 per curse")
	var before: float = player.pollution
	for i in Pietas.POLLUTION_DECAY_TICKS * 3:
		sim.step()
	check(player.pollution < before, "wears off")


func test_pollution_halves_heavenly_and_strengthens_underworld() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	sim.queue_item_action(PLAYER, "bless", {"blessing": "mars_fury"})
	sim.queue_item_action(PLAYER, "bless", {"blessing": "hecate_whisper"})
	sim.step()
	check(is_equal_approx(player.blessing_boosts["strength"], 0.1), "full strength while clean")
	_cast(sim, 8)
	check(Pietas.is_polluted(player), "polluted after 8 curses")
	check(is_equal_approx(player.blessing_boosts["strength"], 0.05), "heavenly halved")
	check(is_equal_approx(player.blessing_boosts["ritus"], 0.12), "underworld x1.5")


func test_heavenly_altar_refuses_the_polluted_but_underworld_does_not() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.pollution = 50.0
	player.favour = 1.0
	sim.pietas.add_altar("heavenly", player.position + Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "pray")
	var events := sim.step()
	check_eq(player.favour, 1.0, "no favour from the heavenly altar")
	check(events.any(func(e): return e["type"] == "message" and "turn from you" in e["text"]), "told why")
	sim.pietas.altars.clear()
	sim.pietas.add_altar("underworld", player.position + Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "pray")
	sim.step()
	check(player.favour > 1.0, "the underworld altar still answers")


func test_washing_in_a_spring_clears_pollution() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.pollution = 60.0
	sim.pietas.add_spring(player.position + Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "wash")
	for i in Pietas.WASH_TICKS + 1:
		sim.step()
	check_eq(player.pollution, 0.0, "clean")


func test_the_sacerdos_cleanses_for_a_fee() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.pollution = 40.0
	sim.pietas.set_priest(player.position + Vector3(1, 0, 0))
	sim.queue_item_action(PLAYER, "cleanse")
	sim.step()
	check_eq(player.pollution, 0.0, "cleansed")
	check_eq(player.inventory.count("coins"), 100 - Pietas.CLEANSING_FEE, "paid")


func test_cursing_in_town_warns_then_fines() -> void:
	var sim := _make_sim(Vector3(5, 0, 5))
	var events := _cast(sim, 1)
	check(events.any(func(e): return e["type"] == "watch_warning"), "first: a warning")
	check_eq(sim.get_combatant(PLAYER).inventory.count("coins"), 100, "no fine yet")
	events = _cast(sim, 1)
	check(events.any(func(e): return e["type"] == "watch_fine"), "second: a fine")
	check_eq(sim.get_combatant(PLAYER).inventory.count("coins"), 100 - Pietas.WATCH_FINE, "fined 25")


func test_no_watch_outside_town() -> void:
	var sim := _make_sim()
	var events := _cast(sim, 3)
	check(not events.any(func(e): return e["type"] in ["watch_warning", "watch_fine"]), "the watch stays in town")


func test_the_watch_fines_at_most_once_a_minute() -> void:
	var sim := _make_sim(Vector3(5, 0, 5))
	_cast(sim, 6)
	check_eq(sim.get_combatant(PLAYER).inventory.count("coins"), 100 - Pietas.WATCH_FINE, "one fine for a quick burst of curses")
