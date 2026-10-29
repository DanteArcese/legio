extends "res://tests/test_case.gd"
## Protection blessings: each turns aside most of one kind of blow, only one
## can be up at a time, pollution weakens or strengthens them like any
## blessing, and monsters land the kind of blow their content says.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const Combat := preload("res://scripts/sim/combat.gd")
const Pietas := preload("res://scripts/sim/pietas.gd")

const PLAYER := 1
const MONSTER := 50


func _make_sim(level := 46) -> Simulation:
	var sim := Simulation.new(5)
	var player := sim.add_player(PLAYER)
	player.skills.xp["pietas"] = Skills.xp_for_level(level)
	player.favour = float(level)
	return sim


func _bless(sim: Simulation, id: String) -> void:
	sim.queue_item_action(PLAYER, "bless", {"blessing": id})
	sim.step()


func test_protection_takes_most_of_a_matching_blow() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	_bless(sim, "minerva_shield")
	check_eq(player.blessings, ["minerva_shield"], "shield up")
	check_eq(Combat.protected(player, "melee", 10), 4, "60% of a melee blow turned aside")
	check_eq(Combat.protected(player, "ranged", 10), 10, "nothing against arrows")
	player.blessing_boosts["protect_melee"] = 1.0
	check_eq(Combat.protected(player, "melee", 10), 2, "never more than the cap")


func test_one_protection_at_a_time() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	_bless(sim, "minerva_shield")
	_bless(sim, "hecate_ward")
	check_eq(player.blessings, ["hecate_ward"], "the ward replaces the shield")
	check(not player.blessing_boosts.has("protect_melee"), "melee protection gone")


func test_levels_and_pollution() -> void:
	var sim := _make_sim(42)
	var player: RefCounted = sim.get_combatant(PLAYER)
	_bless(sim, "diana_veil")
	check(player.blessings.is_empty(), "the veil needs Pietas 43")
	sim = _make_sim()
	player = sim.get_combatant(PLAYER)
	player.pollution = Pietas.POLLUTED_AT
	_bless(sim, "minerva_shield")
	check(is_equal_approx(player.blessing_boosts["protect_melee"], 0.3), "polluted, Minerva's shield is half as strong")
	_bless(sim, "hecate_ward")
	check(is_equal_approx(player.blessing_boosts["protect_ritus"], 0.9), "and Hecate's ward stronger")
	check_eq(Combat.protected(player, "ritus", 10), 2, "though still capped")


func test_monsters_land_their_kind_of_blow() -> void:
	var sim := _make_sim()
	check_eq(sim.add_monster(MONSTER, "lemur", Vector3.ZERO).attack_type(), "ritus", "a lemur's touch is a curse")
	check_eq(sim.add_monster(MONSTER + 1, "lemur", Vector3.ZERO).combat_kind(), "melee", "though it fights up close")
	check_eq(sim.add_monster(MONSTER + 2, "wolf", Vector3.ZERO).attack_type(), "melee", "a wolf bites")
	check_eq(sim.get_combatant(PLAYER).attack_type(), "melee", "a player's blow is their weapon's")


func test_protected_fight_takes_less_damage() -> void:
	var taken := []
	for protect in [false, true]:
		var sim := _make_sim()
		var player: RefCounted = sim.get_combatant(PLAYER)
		player.max_hp = 1000
		player.hp = 1000
		player.auto_retaliate = false
		if protect:
			_bless(sim, "hecate_ward")
			player.favour = 1000.0
		var lemur := sim.add_monster(MONSTER, "lemur", Vector3(0, 0, 1))
		lemur.target_id = PLAYER
		for i in 300:
			sim.step()
			if protect and player.blessings.is_empty():
				_bless(sim, "hecate_ward")
		taken.append(1000 - player.hp)
	check(taken[0] > 0, "the lemur hurts (%d)" % taken[0])
	check(taken[1] < taken[0] * 0.6, "the ward takes most of it (%d vs %d)" % [taken[1], taken[0]])
