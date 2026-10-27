extends "res://tests/test_case.gd"
## The Hydra: its wounds close every tick unless seared by a firepot.

const Simulation := preload("res://scripts/sim/simulation.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")
const Skills := preload("res://scripts/sim/skills.gd")

const PLAYER := 1
const HYDRA := 50


func _make_sim() -> Simulation:
	var sim := Simulation.new(31)
	var player := sim.add_player(PLAYER, Vector3.ZERO)
	player.max_hp = 1000
	player.hp = 1000
	player.auto_retaliate = false
	var hydra := sim.add_monster(HYDRA, "hydra", Vector3(1, 0, 0))
	hydra.target_id = PLAYER
	player.target_id = -1
	return sim


func test_the_hydra_heals_unless_seared() -> void:
	var sim := _make_sim()
	var hydra: RefCounted = sim.get_combatant(HYDRA)
	hydra.hp = 50
	var events := []
	for i in 5:
		events.append_array(sim.step())
	check(hydra.hp >= 58, "healed 2 a tick (%d)" % hydra.hp)
	check(events.any(func(e): return e["type"] == "message" and "Sear them with fire" in e["text"]), "the player is told")
	hydra.hp = 50
	hydra.seared_until = sim.tick + 10
	for i in 5:
		sim.step()
	check_eq(hydra.hp, 50, "seared: no healing")


func test_a_firepot_sears_and_burns() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	var hydra: RefCounted = sim.get_combatant(HYDRA)
	hydra.hp = 80
	sim.give_item(PLAYER, "firepot", 2, "test", [])
	player.target_id = HYDRA
	var slot: int = player.inventory.slots.find(player.inventory.slots.filter(func(s): return s != null and s["item"] == "firepot")[0])
	sim.queue_item_action(PLAYER, "throw", {"slot": slot})
	var events := sim.step()
	check(hydra.seared_until > sim.tick, "seared")
	check(events.any(func(e): return e["type"] == "hit" and e["kind"] == "fire"), "a fire hit")
	check_eq(player.inventory.count("firepot"), 1, "one thrown")


func test_firepots_need_a_target_in_range() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	sim.give_item(PLAYER, "firepot", 1, "test", [])
	var events := []
	sim.queue_item_action(PLAYER, "throw", {"slot": 0})
	events.append_array(sim.step())
	check_eq(player.inventory.count("firepot"), 1, "kept with no target")
	check(events.any(func(e): return e["type"] == "message" and "Attack something first" in e["text"]), "told why")


func test_firepots_are_fired_in_the_kiln_from_pots_and_olives() -> void:
	var recipe := ContentDB.recipe("kiln", "firepot")
	check(not recipe.is_empty(), "a kiln recipe")
	check(recipe["inputs"].any(func(e): return e["item"] == "clay_pot") and recipe["inputs"].any(func(e): return e["item"] == "olives"), "pot and olives")
