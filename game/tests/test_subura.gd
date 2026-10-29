extends "res://tests/test_case.gd"
## The Subura: Thieving content past 55, and in Rome the urban cohorts
## (a warning, then a 75-denarius fine) where the fort has the vigiles.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const Pietas := preload("res://scripts/sim/pietas.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const ROME_SPOT := Vector3(-530, 0, -17)


func test_subura_content_reaches_85() -> void:
	var levels := []
	for kind in ["stalls", "marks", "strongboxes"]:
		for entry in ContentDB.data()["thieving"][kind].values():
			levels.append(entry["level"])
	check(levels.max() >= 85, "something at Thieving 85")
	check(levels.filter(func(l): return l >= 60).size() >= 6, "six targets past 60")


func test_rome_is_the_urban_cohorts_beat() -> void:
	check(Pietas.in_rome(ROME_SPOT), "the Subura is in Rome")
	check(not Pietas.in_rome(Vector3(0, 0, 0)), "the fort isn't")


func test_caught_in_rome() -> void:
	var sim := Simulation.new(9)
	var player := sim.add_player(PLAYER)
	player.skills.xp["thieving"] = Skills.xp_for_level(60)
	player.position = ROME_SPOT
	sim.give_item(PLAYER, "coins", 500, "test", [])
	var mark := 70
	sim.thieving.add_mark(mark, "gambler", ROME_SPOT + Vector3(1, 0, 0))
	var texts := []
	for i in 200:
		player.stunned_until = 0
		player.thieving_ready_at = 0
		sim.queue_item_action(PLAYER, "pickpocket", {"mark": mark})
		for e in sim.step():
			if e["type"] == "message":
				texts.append(e["text"])
		if texts.any(func(t): return "urban cohorts fine you 75" in t):
			break
	check(texts.any(func(t): return "urban cohorts" in t and "warning" in t), "a warning first")
	check(texts.any(func(t): return "urban cohorts fine you 75" in t), "then the cohorts' fine")
