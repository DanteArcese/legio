extends "res://tests/test_case.gd"
## Pietas from 70 to 99: the last blessings (Jupiter's Thunderbolt protects
## and turns blows back; the Capitoline Triad at 99) and consecrating
## jewellery at Rome's altar of Jupiter.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const WOLF := 60


func _make_sim(pietas := 99) -> Simulation:
	var sim := Simulation.new(6)
	var player := sim.add_player(PLAYER)
	player.skills.xp["pietas"] = Skills.xp_for_level(pietas)
	player.favour = float(pietas)
	return sim


func _bless(sim: Simulation, id: String) -> void:
	sim.queue_item_action(PLAYER, "bless", {"blessing": id})
	sim.step()


func test_blessings_reach_99() -> void:
	var levels: Array = ContentDB.data()["pietas"]["blessings"].values().map(func(b): return b["level"])
	check_eq(levels.max(), 99, "the Triad at 99")
	for band in [[70, 80], [80, 90], [90, 99]]:
		check(levels.any(func(l): return l >= band[0] and l <= band[1]), "a blessing between %d and %d" % band)


func test_thunderbolt_protects_and_turns_blows_back() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.skills.xp["vitality"] = Skills.xp_for_level(99)
	player.max_hp = 99
	player.hp = 99
	player.auto_retaliate = false
	_bless(sim, "jupiter_thunderbolt")
	check(player.blessing_boosts.get("protect_melee", 0.0) > 0.0, "a melee protection")
	var wolf := sim.add_monster(WOLF, "dire_wolf", Vector3(0, 0, 1))
	wolf.max_hp = 1000
	wolf.hp = 1000
	wolf.target_id = PLAYER
	var back := 0
	for i in 60:
		player.favour = 99.0
		for e in sim.step():
			if e["type"] == "hit" and e.get("kind", "") == "reflect":
				back += e["damage"]
	check(back > 0, "the wolf hurt by its own blows (%d)" % back)


func test_consecration_at_the_altar_of_jupiter() -> void:
	var sim := _make_sim(80)
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.skills.xp["defence"] = Skills.xp_for_level(40)
	sim.pietas.add_altar("heavenly", Vector3(1, 0, 0), true)
	sim.give_item(PLAYER, "coins", 1000, "test", [])
	sim.give_item(PLAYER, "gold_bulla", 1, "test", [])
	var slots: Array = player.inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == "gold_bulla":
			sim.queue_item_action(PLAYER, "equip", {"slot": i})
			sim.step()
			break
	var defence: int = player.bonuses["defence"]
	sim.queue_item_action(PLAYER, "consecrate", {"item": "gold_bulla"})
	sim.step()
	check(player.consecrated.has("gold_bulla"), "consecrated")
	check_eq(player.bonuses["defence"], defence + 2, "the worn bulla gives a little more")
	check_eq(player.inventory.count("coins"), 500, "for the priests' fee")
	sim.queue_item_action(PLAYER, "consecrate", {"item": "bronze_gladius"})
	sim.step()
	check(not player.consecrated.has("bronze_gladius"), "jewellery only")


func test_only_at_a_consecrating_altar() -> void:
	var sim := _make_sim(80)
	var player: RefCounted = sim.get_combatant(PLAYER)
	sim.pietas.add_altar("heavenly", Vector3(1, 0, 0))
	sim.give_item(PLAYER, "coins", 1000, "test", [])
	sim.give_item(PLAYER, "silver_pendant", 1, "test", [])
	sim.queue_item_action(PLAYER, "consecrate", {"item": "silver_pendant"})
	sim.step()
	check(player.consecrated.is_empty(), "not at the fort's altar")
