extends "res://tests/test_case.gd"
## Lamiae charm the unwarded (their blows land and you can't eat), and a
## leather or gold bulla wards it; centaurs loose arrows from range.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")

const PLAYER := 1
const LAMIA := 80


func _make_sim(neck := "") -> Simulation:
	var sim := Simulation.new(8)
	var player := sim.add_player(PLAYER)
	player.skills.xp["vitality"] = Skills.xp_for_level(99)
	player.skills.xp["defence"] = Skills.xp_for_level(40)
	player.max_hp = 99
	player.hp = 99
	player.auto_retaliate = false
	if not neck.is_empty():
		sim.give_item(PLAYER, neck, 1, "test", [])
		_act(sim, "equip", {"slot": _slot(sim, neck)})
	var lamia := sim.add_monster(LAMIA, "lamia", Vector3(0, 0, 1))
	lamia.target_id = PLAYER
	return sim


func _act(sim: Simulation, action: String, args := {}) -> Array:
	sim.queue_item_action(PLAYER, action, args)
	return sim.step()


func _slot(sim: Simulation, item_id: String) -> int:
	var slots: Array = sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			return i
	return -1


func _run_until_hit(sim: Simulation) -> Array:
	var events := []
	for i in 30:
		var step := sim.step()
		events.append_array(step)
		if step.any(func(e): return e["type"] == "hit" and e["attacker"] == LAMIA):
			break
	return events


func test_unwarded_lamia_charms() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	var events := _run_until_hit(sim)
	check(events.any(func(e): return e["type"] == "hit" and e["attacker"] == LAMIA and e["damage"] > 0), "her blow lands")
	check(sim.tick < player.charmed_until, "and charms")
	check(events.any(func(e): return e["type"] == "message" and "look away" in e["text"]), "told why")
	var hp: int = player.hp
	sim.give_item(PLAYER, "bread", 1, "test", [])
	var bread := _slot(sim, "bread")
	events = _act(sim, "eat", {"slot": bread})
	check(events.any(func(e): return e["type"] == "message" and "eyes off her" in e["text"]), "can't eat while charmed")
	check(player.hp <= hp, "no healing")


func test_a_bulla_wards_the_charm() -> void:
	for neck in ["leather_bulla", "gold_bulla"]:
		var sim := _make_sim(neck)
		sim.get_combatant(PLAYER).skills.xp["defence"] = Skills.xp_for_level(40)
		_run_until_hit(sim)
		check(sim.tick >= sim.get_combatant(PLAYER).charmed_until, "the %s wards it" % neck)


func test_centaurs_shoot_from_range() -> void:
	var sim := Simulation.new(8)
	var player := sim.add_player(PLAYER)
	player.max_hp = 99
	player.hp = 99
	player.auto_retaliate = false
	var centaur := sim.add_monster(LAMIA, "centaur", Vector3(0, 0, 6))
	check_eq(centaur.attack_type(), "ranged", "a bowman")
	check_eq(centaur.reach, 7.0, "with a bow's reach")
	centaur.target_id = PLAYER
	var shot := false
	for i in 20:
		for e in sim.step():
			if e["type"] == "hit" and e["attacker"] == LAMIA:
				shot = e["ranged"]
		if shot:
			break
	check(shot, "looses an arrow")
	check(sim.flat_distance(centaur.position, player.position) > 4.0, "from where he stood")
