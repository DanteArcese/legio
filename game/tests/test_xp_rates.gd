extends "res://tests/test_case.gd"
## XP rates on the training dummy: 10 minutes of game time per melee style
## should take a fresh character to level 5+ in that style's skill.

const Simulation := preload("res://scripts/sim/simulation.gd")

const PLAYER := 1
const DUMMY := 100
const TEN_MINUTES := 1000 # ticks at 0.6 s


func test_ten_minutes_per_style_reaches_level_five() -> void:
	var sim := Simulation.new(3)
	sim.add_player(PLAYER)
	var dummy := sim.add_combatant(DUMMY)
	dummy.max_hp = 1000
	dummy.hp = 1000
	dummy.can_fight = false
	dummy.auto_retaliate = false
	dummy.position = Vector3(1, 0, 1)
	var skills: RefCounted = sim.get_combatant(PLAYER).skills
	for style in ["accurate", "aggressive", "defensive"]:
		sim.queue_style(PLAYER, style)
		for i in TEN_MINUTES:
			if sim.get_combatant(PLAYER).target_id == -1:
				sim.queue_attack(PLAYER, DUMMY)
			sim.step()
	check(skills.level("attack") >= 5, "accurate reaches attack 5+ (got %d)" % skills.level("attack"))
	check(skills.level("strength") >= 5, "aggressive reaches strength 5+ (got %d)" % skills.level("strength"))
	check(skills.level("defence") >= 5, "defensive reaches defence 5+ (got %d)" % skills.level("defence"))
	check(skills.level("vitality") > 1, "vitality trains alongside")
