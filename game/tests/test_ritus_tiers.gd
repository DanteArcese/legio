extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")

const PLAYER := 1
const TARGET := 2


func _make_sim(tablet: String, target_fights := false) -> Simulation:
	var sim := Simulation.new(9)
	var player := sim.add_player(PLAYER, Vector3(40, 0, 40))
	player.skills.xp["ritus"] = Skills.xp_for_level(60)
	player.bonuses["ritus_attack"] = 5000
	for item in [["lituus", 1], [tablet, 50]]:
		sim.give_item(PLAYER, item[0], item[1], "test", [])
		sim.queue_item_action(PLAYER, "equip", {"slot": _slot_of(sim, item[0])})
		sim.step()
	player.bonuses["ritus_attack"] = 5000
	var target := sim.add_combatant(TARGET)
	target.max_hp = 1000
	target.hp = 1000
	target.can_fight = target_fights
	target.attack_speed = 4
	target.position = Vector3(44, 0, 40)
	return sim


func _slot_of(sim: Simulation, item_id: String) -> int:
	var slots: Array = sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1


func _run(sim: Simulation, ticks: int) -> Array:
	var events := []
	for i in ticks:
		events.append_array(sim.step())
	return events


func test_silenced_target_misses_its_next_attack() -> void:
	var sim := _make_sim("silencing_tablet", true)
	var target: RefCounted = sim.get_combatant(TARGET)
	target.bonuses["attack"] = 5000
	target.target_id = PLAYER
	target.reach = 10.0
	sim.queue_attack(PLAYER, TARGET)
	var events := _run(sim, 12)
	check(events.any(func(e): return e["type"] == "curse" and e["curse"] == "silencing"), "silencing landed")
	check(events.any(func(e): return e["type"] == "silenced_miss" and e["id"] == TARGET), "its next attack fell on nothing")


func test_the_manes_shade_fights_the_casters_target() -> void:
	var sim := _make_sim("manes_tablet")
	sim.queue_attack(PLAYER, TARGET)
	var events := _run(sim, 20)
	var summon: Array = events.filter(func(e): return e["type"] == "summon")
	check_eq(summon.size(), 1, "one shade, refreshed rather than duplicated")
	var shade_id: int = summon[0]["id"]
	check(events.any(func(e): return e["type"] == "hit" and e["attacker"] == shade_id), "the shade attacks")


func test_the_shade_fades_and_its_kills_count_for_the_caster() -> void:
	var sim := _make_sim("manes_tablet")
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.slayer_task = {"monster": "rat", "remaining": 2, "total": 2, "venator": "aulus"}
	var rat := sim.add_monster(50, "rat", Vector3(44, 0, 41))
	rat.hp = 20
	rat.max_hp = 20
	player.bonuses["ritus_strength"] = -100
	sim.queue_attack(PLAYER, 50)
	var events := _run(sim, 40)
	check(events.any(func(e): return e["type"] == "death" and e["id"] == 50), "the rat died")
	check_eq(player.slayer_task.get("remaining", 0), 1, "the kill counted for the caster")
	sim.queue_stop(PLAYER)
	events = _run(sim, Simulation.Curses.SHADE_LIFETIME + 2)
	check(events.any(func(e): return e["type"] == "summon_end"), "the shade fades")
	check(sim.get_combatant(Simulation.Curses.SHADE_ID_BASE + PLAYER) == null, "and is gone")


func test_new_tablets_need_their_ritus_levels() -> void:
	var sim := Simulation.new()
	sim.add_player(PLAYER)
	sim.give_item(PLAYER, "silencing_tablet", 5, "test", [])
	sim.give_item(PLAYER, "manes_tablet", 5, "test", [])
	sim.queue_item_action(PLAYER, "equip", {"slot": 0})
	var events := sim.step()
	check(events.any(func(e): return e["type"] == "message" and "Ritus 30" in e["text"]), "silencing needs 30")
	sim.queue_item_action(PLAYER, "equip", {"slot": 1})
	events = sim.step()
	check(events.any(func(e): return e["type"] == "message" and "Ritus 50" in e["text"]), "manes needs 50")


func test_manes_and_silencing_tablets_are_inscribed_at_the_tomb() -> void:
	var sim := Simulation.new()
	var player := sim.add_player(PLAYER)
	player.skills.xp["ritus"] = Skills.xp_for_level(55)
	sim.skilling.add_station("tomb", Vector3(1, 0, 0))
	for item in [["stylus", 1], ["lead_sheet", 4], ["iron_nails", 15], ["strix_feather", 4], ["lemur_ash", 2]]:
		sim.give_item(PLAYER, item[0], item[1], "test", [])
	var messages := []
	for recipe in ["silencing_tablet", "manes_tablet"]:
		sim.queue_item_action(PLAYER, "craft", {"kind": "inscribe", "recipe": recipe, "count": 2})
		for i in 12:
			messages.append_array(sim.step().filter(func(e): return e["type"] == "message").map(func(e): return e["text"]))
	check_eq(player.inventory.count("silencing_tablet"), 10, "silencing (%s)" % [messages])
	check_eq(player.inventory.count("manes_tablet"), 6, "manes (%s)" % [messages])
