extends "res://tests/test_case.gd"
## Blessings from Pietas 30 to 70: a stronger tier of each boost, Jupiter's
## Attack, and Proserpina's harvest (Ritus damage heals you).

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const RAT := 70


func _make_sim(level := 70) -> Simulation:
	var sim := Simulation.new(6)
	var player := sim.add_player(PLAYER)
	player.skills.xp["pietas"] = Skills.xp_for_level(level)
	player.favour = float(level)
	return sim


func _bless(sim: Simulation, id: String) -> void:
	sim.queue_item_action(PLAYER, "bless", {"blessing": id})
	sim.step()


func test_every_level_band_has_blessings() -> void:
	var levels: Array = ContentDB.data()["pietas"]["blessings"].values().map(func(b): return b["level"])
	for band in [[30, 40], [40, 50], [50, 60], [60, 70]]:
		check(levels.any(func(l): return l >= band[0] and l <= band[1]), "a blessing between %d and %d" % band)
	check(levels.max() >= 70, "something at 70")


func test_jupiter_raises_attack_and_replaces_his_lesser_self() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.skills.xp["attack"] = Skills.xp_for_level(60)
	var before: int = player.effective_level("attack")
	_bless(sim, "jupiter_thunder")
	check_eq(player.effective_level("attack"), before + 6, "+10% of 60")
	_bless(sim, "jupiter_majesty")
	check_eq(player.blessings, ["jupiter_majesty"], "the Majesty replaces the Thunder")
	check_eq(player.effective_level("attack"), before + 12, "+20% of 60")


func test_tiers_replace_the_lower_one() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	_bless(sim, "mars_fury")
	_bless(sim, "mars_wrath")
	check_eq(player.blessings, ["mars_wrath"], "one strength blessing at a time")


func test_harvest_heals_on_ritus_damage() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.skills.xp["ritus"] = Skills.xp_for_level(60)
	# At Vitality 99 no level-up resets the hitpoints mid-test.
	player.skills.xp["vitality"] = Skills.xp_for_level(99)
	player.max_hp = 99
	player.hp = 10
	sim.give_item(PLAYER, "lituus", 1, "test", [])
	sim.give_item(PLAYER, "binding_tablet", 200, "test", [])
	for item in ["lituus", "binding_tablet"]:
		var slots: Array = player.inventory.slots
		for i in slots.size():
			if slots[i] and slots[i]["item"] == item:
				sim.queue_item_action(PLAYER, "equip", {"slot": i})
				sim.step()
				break
	_bless(sim, "proserpina_harvest")
	var dummy := sim.add_combatant(RAT)
	dummy.max_hp = 100000
	dummy.hp = 100000
	dummy.can_fight = false
	dummy.position = Vector3(0, 0, 2)
	player.target_id = RAT
	var expected := 0
	for i in 150:
		player.favour = 70.0
		var before: int = player.hp
		var events := sim.step()
		for e in events:
			if e["type"] == "hit" and e["attacker"] == PLAYER and e["damage"] > 0:
				expected += floori(e["damage"] * 0.25)
				check(player.hp >= before + floori(e["damage"] * 0.25) - 1, "healed by a quarter of the blow (hp %d -> %d, blow %d, kind %s)" % [before, player.hp, e["damage"], e.get("kind", "?")])
		player.hp = mini(player.hp, 10)
	check(expected > 0, "some curses bit hard enough to feed on")
