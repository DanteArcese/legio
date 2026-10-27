extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const DeathRules := preload("res://scripts/sim/death_rules.gd")
const SaveGame := preload("res://scripts/sim/save_game.gd")

const PLAYER := 1
const DUMMY := 2


## A player with a bow and 20 bronze arrows, 5 m from a sturdy dummy.
func _make_sim(arrows := 20) -> Simulation:
	var sim := Simulation.new(17)
	sim.add_player(PLAYER)
	sim.give_item(PLAYER, "hunting_bow", 1, "test", [])
	sim.give_item(PLAYER, "bronze_arrow", arrows, "test", [])
	_equip(sim, "hunting_bow")
	_equip(sim, "bronze_arrow")
	var dummy := sim.add_combatant(DUMMY)
	dummy.max_hp = 1000
	dummy.hp = 1000
	dummy.can_fight = false
	dummy.position = Vector3(5, 0, 0)
	return sim


func _player(sim: Simulation) -> RefCounted:
	return sim.get_combatant(PLAYER)


func _equip(sim: Simulation, item_id: String) -> void:
	var slots: Array = _player(sim).inventory.slots
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


func test_bow_switches_to_ranged_styles() -> void:
	var sim := _make_sim()
	var player: RefCounted = _player(sim)
	check(player.is_ranged(), "ranged with a bow")
	check_eq(player.style, "aimed", "style switched to a ranged style")
	check_eq(player.equipment.ammo_count, 20, "whole stack worn")
	check_eq(player.bonuses["ranged_strength"], 6, "ammo bonus applies")


func test_attacks_from_range_and_uses_ammo() -> void:
	var sim := _make_sim()
	sim.queue_attack(PLAYER, DUMMY)
	var events := _run(sim, 9)
	var shots := events.filter(func(e): return e["type"] == "hit" and e["attacker"] == PLAYER)
	check_eq(shots.size(), 3, "three shots at speed 4 from 5 m away")
	check(shots.all(func(e): return e["ranged"]), "marked as ranged")
	check_eq(_player(sim).equipment.ammo_count, 17, "one arrow per shot")


func test_out_of_bow_range_does_not_fire() -> void:
	var sim := _make_sim()
	sim.set_position(DUMMY, Vector3(9, 0, 0))
	sim.queue_attack(PLAYER, DUMMY)
	check_eq(_run(sim, 8).filter(func(e): return e["type"] == "hit").size(), 0, "9 m is beyond 7 m")
	sim.queue_style(PLAYER, "longrange")
	check(_run(sim, 8).filter(func(e): return e["type"] == "hit").size() > 0, "longrange adds 2 m")


func test_most_ammo_lands_near_the_target_in_one_pile() -> void:
	var sim := _make_sim(40)
	sim.queue_attack(PLAYER, DUMMY)
	_run(sim, 160)
	var piles := sim.ground_piles()
	check_eq(piles.size(), 1, "shots pile up in one place")
	var recovered: int = piles[0]["items"][0]["quantity"]
	check(recovered >= 20 and recovered <= 38, "about three quarters recoverable (%d of 40)" % recovered)


func test_running_out_of_ammo_stops_attacking() -> void:
	var sim := _make_sim(2)
	sim.queue_attack(PLAYER, DUMMY)
	var events := _run(sim, 16)
	check_eq(events.filter(func(e): return e["type"] == "hit").size(), 2, "only two arrows")
	check_eq(_player(sim).equipment.worn["ammo"], "", "ammo slot empty")
	check_eq(_player(sim).target_id, -1, "stopped attacking")
	check(events.any(func(e): return e["type"] == "message" and "no suitable ammunition" in e["text"]), "told why")


func test_wrong_ammo_type_does_not_fire() -> void:
	var sim := _make_sim(0)
	sim.give_item(PLAYER, "lead_glans", 10, "test", [])
	_equip(sim, "lead_glans")
	sim.queue_attack(PLAYER, DUMMY)
	check_eq(_run(sim, 8).filter(func(e): return e["type"] == "hit").size(), 0, "sling bullets don't fit a bow")


func test_ranged_xp_and_longrange_defence_split() -> void:
	var sim := _make_sim(200)
	var player: RefCounted = _player(sim)
	player.bonuses["ranged_attack"] = 5000
	sim.queue_attack(PLAYER, DUMMY)
	_run(sim, 40)
	check(player.skills.xp["ranged"] > 0.0, "ranged xp")
	check_eq(player.skills.xp["defence"], 0.0, "no defence xp when aimed")
	sim.queue_style(PLAYER, "longrange")
	var before: float = player.skills.xp["ranged"]
	_run(sim, 40)
	check(player.skills.xp["defence"] > 0.0, "longrange trains defence")
	check(is_equal_approx(player.skills.xp["ranged"] - before, player.skills.xp["defence"]), "split evenly")


func test_rapid_fires_faster() -> void:
	var sim := _make_sim(50)
	sim.queue_style(PLAYER, "rapid")
	sim.queue_attack(PLAYER, DUMMY)
	var shots := _run(sim, 12).filter(func(e): return e["type"] == "hit")
	check_eq(shots.size(), 4, "every 3 ticks instead of 4")


func test_melee_styles_rejected_with_a_bow() -> void:
	var sim := _make_sim()
	sim.queue_style(PLAYER, "aggressive")
	sim.step()
	check_eq(_player(sim).style, "aimed", "can't pick a melee style")


func test_ammo_stacks_merge_and_unequip_returns_the_stack() -> void:
	var sim := _make_sim(20)
	sim.give_item(PLAYER, "bronze_arrow", 30, "test", [])
	_equip(sim, "bronze_arrow")
	check_eq(_player(sim).equipment.ammo_count, 50, "stacks merged")
	sim.queue_item_action(PLAYER, "unequip", {"equip_slot": "ammo"})
	sim.step()
	check_eq(_player(sim).inventory.count("bronze_arrow"), 50, "whole stack back")
	check_eq(_player(sim).equipment.ammo_count, 0, "slot empty")


func test_combat_level_counts_ranged() -> void:
	var skills := Skills.new()
	skills.xp["ranged"] = Skills.xp_for_level(40)
	check(skills.combat_level() > Skills.new().combat_level() + 15, "ranged raises combat level (%d)" % skills.combat_level())
	for skill in ["ranged", "defence", "vitality"]:
		skills.xp[skill] = Skills.xp_for_level(99)
	check_eq(skills.combat_level(), 99, "a maxed ranger is 99")


func test_ammo_survives_save_and_death_rules() -> void:
	var sim := _make_sim(33)
	var data := SaveGame.capture(sim, PLAYER)
	var fresh := Simulation.new()
	fresh.add_player(PLAYER)
	SaveGame.restore(fresh, PLAYER, SaveGame.from_json(SaveGame.to_json(data)))
	check_eq(fresh.get_combatant(PLAYER).equipment.ammo_count, 33, "ammo count saved")
	var split := DeathRules.split(_player(sim).inventory, _player(sim).equipment)
	var all: Array = split["lost"] + split["kept_inventory"]
	var arrows: Array = all.filter(func(e): return e["item"] == "bronze_arrow")
	check(split["kept_worn"].has("ammo") or (arrows.size() == 1 and arrows[0]["quantity"] == 33), "the arrow stack is handled as one entry")


func test_shop_sells_arrow_bundles() -> void:
	var sim := Simulation.new()
	sim.add_player(PLAYER)
	sim.add_shopkeeper("aulus", Vector3(1, 0, 0))
	sim.give_item(PLAYER, "coins", 100, "test", [])
	sim.queue_item_action(PLAYER, "buy", {"shop": "aulus", "item": "bronze_arrow"})
	sim.step()
	check_eq(sim.get_combatant(PLAYER).inventory.count("bronze_arrow"), 50, "50 arrows")
	check_eq(sim.get_combatant(PLAYER).inventory.count("coins"), 25, "for 75 denarii")


## An amentum throws javelins: shorter range and slower than a bow, but
## each throw hits harder, and arrows don't fit the strap.
func test_amentum_throws_javelins() -> void:
	var sim := _make_sim()
	var player: RefCounted = _player(sim)
	sim.give_item(PLAYER, "amentum", 1, "test", [])
	sim.give_item(PLAYER, "bronze_javelin", 10, "test", [])
	_equip(sim, "amentum")
	check(player.is_ranged(), "ranged with an amentum")
	check_eq(_run(sim, 8).filter(func(e): return e["type"] == "hit").size(), 0, "arrows don't fit an amentum")
	sim.queue_attack(PLAYER, -1)
	_equip(sim, "bronze_javelin")
	check_eq(player.equipment.ammo_count, 10, "javelins worn as ammo")
	check_eq(player.attack_range(), 5.0, "shorter reach than a bow")
	check_eq(player.attack_speed, 5, "slower than a bow")
	var bow_max: int = CombatMathRef.max_hit(player.effective_level("ranged"), 6)
	check(player.max_hit() >= bow_max, "a javelin hits at least as hard as a bronze arrow")
	sim.queue_attack(PLAYER, DUMMY)
	var events := _run(sim, 12)
	check(events.filter(func(e): return e["type"] == "hit" and e["attacker"] == PLAYER).size() >= 1, "threw at the dummy")
	check(player.equipment.ammo_count < 10, "throws spend javelins")


func test_javelins_need_ranged_levels_and_smith_in_fives() -> void:
	check_eq(ContentDB.item("steel_pilum")["requirements"]["ranged"], 30, "the pilum needs Ranged 30")
	var recipe := ContentDB.recipe("smith", "iron_javelin")
	check_eq(recipe["quantity"], 5, "five javelins a bar")


const CombatMathRef := preload("res://scripts/sim/combat_math.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")
