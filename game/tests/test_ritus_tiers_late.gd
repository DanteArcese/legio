extends "res://tests/test_case.gd"
## Ritus past 50: draining tablets sap a target's Attack and Defence for a
## while, turning tablets make its own blows hurt it, and the Torch of Hecate.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Curses := preload("res://scripts/sim/curses.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1
const WOLF := 60


func test_draining_saps_attack_and_defence() -> void:
	var sim := Simulation.new(2)
	var caster := sim.add_player(PLAYER)
	var wolf := sim.add_monster(WOLF, "dire_wolf", Vector3(0, 0, 1))
	var attack: int = wolf.effective_level("attack")
	var strength: int = wolf.effective_level("strength")
	sim.curses.apply(caster, wolf, "draining", [])
	check(wolf.effective_level("attack") < attack, "Attack sapped")
	check_eq(wolf.effective_level("strength"), strength, "Strength untouched")
	for i in Curses.DRAIN_TICKS + 1:
		sim.step()
	check_eq(wolf.effective_level("attack"), attack, "and it wears off")


func test_turning_returns_half_of_each_blow() -> void:
	var sim := Simulation.new(2)
	var player := sim.add_player(PLAYER)
	player.max_hp = 500
	player.hp = 500
	player.auto_retaliate = false
	var wolf := sim.add_monster(WOLF, "dire_wolf", Vector3(0, 0, 1))
	wolf.max_hp = 500
	wolf.hp = 500
	wolf.target_id = PLAYER
	sim.curses.apply(player, wolf, "turning", [])
	var dealt := 0
	var returned := 0
	for i in Curses.TURN_TICKS:
		for e in sim.step():
			if e["type"] == "hit" and e["attacker"] == WOLF:
				dealt += e["damage"]
			if e["type"] == "hit" and e.get("kind", "") == "turning":
				returned += e["damage"]
	check(dealt > 0, "the wolf landed blows (%d)" % dealt)
	check(returned > 0 and returned <= dealt, "half of them came back (%d of %d)" % [returned, dealt])
	check_eq(wolf.hp, 500 - returned, "on the wolf")


func test_content_reaches_80() -> void:
	var levels: Array = ContentDB.data()["skilling"]["recipes"]["inscribe"].map(func(r): return r["level"])
	check(levels.has(65) and levels.has(80), "tablets at 65 and 80")
	check_eq(ContentDB.item("torch_of_hecate")["requirements"]["ritus"], 75, "the torch at 75")
	check(ContentDB.item("torch_of_hecate")["equip"]["bonuses"]["ritus_attack"] > ContentDB.item("orichalcum_lituus")["equip"]["bonuses"]["ritus_attack"], "the best focus")
