extends "res://tests/test_case.gd"
## Medicina past 34: rue antidotes lift a gaze's drains, stronger boosts from
## hellebore and saffron, and theriac, which lifts drains and heals.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1


func _make_sim() -> Simulation:
	var sim := Simulation.new(4)
	var player := sim.add_player(PLAYER)
	for skill in ["attack", "strength", "defence", "vitality"]:
		player.skills.xp[skill] = Skills.xp_for_level(60)
	player.max_hp = 60
	return sim


func _drink(sim: Simulation, item_id: String) -> Array:
	sim.give_item(PLAYER, item_id, 1, "test", [])
	var slots: Array = sim.get_combatant(PLAYER).inventory.slots
	for i in slots.size():
		if slots[i] and slots[i]["item"] == item_id:
			sim.queue_item_action(PLAYER, "drink", {"slot": i})
			return sim.step()
	return []


func test_rue_lifts_drains_not_boosts() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.remedy_boosts["attack"] = {"amount": -6, "next_decay": sim.tick + 100}
	player.remedy_boosts["defence"] = {"amount": -4, "next_decay": sim.tick + 100}
	player.remedy_boosts["strength"] = {"amount": 5, "next_decay": sim.tick + 100}
	_drink(sim, "rue_antidote")
	check(not player.remedy_boosts.has("attack") and not player.remedy_boosts.has("defence"), "drains lifted")
	check_eq(player.remedy_boosts.get("strength", {}).get("amount", 0), 5, "the boost kept")


func test_theriac_lifts_and_heals() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.hp = 20
	player.remedy_boosts["attack"] = {"amount": -8, "next_decay": sim.tick + 100}
	_drink(sim, "theriac")
	check(not player.remedy_boosts.has("attack"), "the drain lifted")
	check_eq(player.hp, 50, "and 30 healed")


func test_hellebore_beats_fennel() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	_drink(sim, "fennel_draught")
	var fennel: int = player.remedy_boosts["strength"]["amount"]
	_drink(sim, "hellebore_draught")
	check(player.remedy_boosts["strength"]["amount"] > fennel, "hellebore is the stronger draught (%d vs %d)" % [player.remedy_boosts["strength"]["amount"], fennel])


func test_herbs_grow_and_mix_to_80() -> void:
	for crop in ["rue", "hellebore", "saffron"]:
		check(not ContentDB.crop(crop).is_empty(), "%s grows" % crop)
	var levels: Array = ContentDB.data()["skilling"]["recipes"]["medicina"].map(func(r): return r["level"])
	check(levels.max() >= 80, "something at Medicina 80")
