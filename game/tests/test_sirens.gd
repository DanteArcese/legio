extends "res://tests/test_case.gd"
## Sirens: their song holds an unwarded player, and wax earplugs (or a
## sealed venator's helm) let you fight back.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Slayer := preload("res://scripts/sim/slayer.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const Skilling := preload("res://scripts/sim/skilling.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const SIREN := 50


func _make_sim(head := "") -> Simulation:
	var sim := Simulation.new(5)
	var player := sim.add_player(PLAYER, Vector3(1, 0, 1))
	for skill in ["attack", "strength", "defence", "vitality", "slayer"]:
		player.skills.xp[skill] = Skills.xp_for_level(40)
	player.hp = player.max_hp
	player.equipment.worn["head"] = head
	player.apply_equipment()
	return sim


## Fights a siren for a while, keeping the player alive. Returns the
## player's hits and the siren's hits.
func _fight(sim: Simulation, ticks := 60) -> Dictionary:
	var player: RefCounted = sim.get_combatant(PLAYER)
	var siren := sim.add_monster(SIREN, "siren", Vector3(1, 0, 1.5))
	siren.hp = 1000
	siren.max_hp = 1000
	player.bonuses["defence"] = 5000
	sim.queue_attack(PLAYER, SIREN)
	var counts := {"player": 0, "siren": 0, "siren_landed": 0, "events": []}
	for i in ticks:
		for e in sim.step():
			counts["events"].append(e)
			if e["type"] == "hit" and e["attacker"] == PLAYER:
				counts["player"] += 1
			elif e["type"] == "hit" and e["attacker"] == SIREN:
				counts["siren"] += 1
				counts["siren_landed"] += 1 if e["damage"] > 0 else 0
		player.hp = player.max_hp
	return counts


func test_an_unwarded_player_is_held_by_the_song() -> void:
	var counts := _fight(_make_sim())
	check(counts["siren"] > 5, "the siren sings (%d)" % counts["siren"])
	check(counts["player"] <= 1, "the player barely strikes (%d)" % counts["player"])
	check_eq(counts["siren_landed"], counts["siren"], "the song always lands despite huge defence")
	check(counts["events"].any(func(e): return e["type"] == "message" and "song holds you" in e["text"]), "told why")


func test_earplugs_let_you_fight() -> void:
	var counts := _fight(_make_sim("wax_earplugs"))
	check(counts["player"] > 8, "free to strike (%d)" % counts["player"])
	check(counts["siren_landed"] <= 1, "huge defence works again (%d landed)" % counts["siren_landed"])


func test_the_sealed_helm_wards_strix_and_sirens() -> void:
	var sim := _make_sim("venators_helm_sealed")
	var player: RefCounted = sim.get_combatant(PLAYER)
	check_eq(Slayer.unwarded_effect("siren", player.equipment), "", "sirens")
	check_eq(Slayer.unwarded_effect("strix", player.equipment), "", "strix")
	player.slayer_task = {"monster": "siren", "remaining": 5, "total": 5, "venator": "aulus"}
	check(Slayer.boost(player, sim.add_monster(SIREN, "siren", Vector3.ZERO)) > 1.0, "still boosts on task")


func test_earplugs_and_the_sealed_helm_are_sewn() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	player.skills.xp["crafting"] = Skills.xp_for_level(35)
	for entry in [["needle", 1], ["beeswax", 2], ["linen", 1], ["venators_helm", 1], ["thread", 1]]:
		sim.give_item(PLAYER, entry[0], entry[1], "test", [])
	sim.queue_item_action(PLAYER, "craft", {"kind": "leatherwork", "recipe": "wax_earplugs", "count": 1})
	for i in 10:
		sim.step()
	check_eq(player.inventory.count("wax_earplugs"), 1, "earplugs")
	check(not Skilling.knows_recipe(player, ContentDB.recipe("leatherwork", "venators_helm_sealed")), "sealing needs the unlock")
	player.slayer_unlocks.append("venators_helm")
	sim.queue_item_action(PLAYER, "craft", {"kind": "leatherwork", "recipe": "venators_helm_sealed", "count": 1})
	for i in 10:
		sim.step()
	check_eq(player.inventory.count("venators_helm_sealed"), 1, "sealed helm")
	check_eq(player.inventory.count("venators_helm"), 0, "the helm went into it")


func test_aulus_sends_slayer_30_players_after_sirens() -> void:
	var tasks := Slayer.eligible_tasks(ContentDB.venator("aulus"), 50, 30).map(func(t): return t["monster"])
	check(tasks.has("siren"), "assigned at Slayer 30")
	tasks = Slayer.eligible_tasks(ContentDB.venator("aulus"), 50, 29).map(func(t): return t["monster"])
	check(not tasks.has("siren"), "not at 29")
