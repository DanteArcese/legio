extends "res://tests/test_case.gd"
## Bosses with stances fight in turns: so many blows of one kind, a tell, then
## the next kind at its own reach; out of the fight they start over.

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")

const PLAYER := 1
const BOSS := 60


func _fight(ticks: int) -> Dictionary:
	var sim := Simulation.new(9)
	var player := sim.add_player(PLAYER)
	player.max_hp = 5000
	player.hp = 5000
	player.auto_retaliate = false
	for skill in ["defence", "vitality"]:
		player.skills.xp[skill] = Skills.xp_for_level(70)
	var boss := sim.add_monster(BOSS, "hrodgar", Vector3(0, 0, 1))
	boss.target_id = PLAYER
	var events := []
	for i in ticks:
		events.append_array(sim.step())
		# Throws land where you stand; this test is about the blows.
		sim.boss.strikes.clear()
	return {"sim": sim, "events": events, "boss": boss}


func test_blows_come_in_stances() -> void:
	var fight := _fight(120)
	var kinds := []
	for event in fight["events"]:
		if event["type"] == "hit" and event["attacker"] == BOSS:
			kinds.append(event["kind"])
	check(kinds.size() >= 9, "enough blows to see a cycle (%d)" % kinds.size())
	check_eq(kinds.slice(0, 4), ["melee", "melee", "melee", "melee"], "four melee blows first")
	check_eq(kinds.slice(4, 7), ["ranged", "ranged", "ranged"], "then three thrown")
	check_eq(kinds[7], "melee", "then back to melee")
	var ranged: Array = fight["events"].filter(func(e): return e["type"] == "hit" and e["attacker"] == BOSS and e["kind"] == "ranged")
	check(ranged.all(func(e): return e.get("ammo", "") == "javelin" and e["ranged"]), "thrown blows fly as javelins")


func test_each_stance_is_told_before_its_first_blow() -> void:
	var fight := _fight(120)
	var events: Array = fight["events"]
	var told := -1
	for i in events.size():
		var event: Dictionary = events[i]
		if event["type"] == "message" and "hefts a framea" in event["text"]:
			told = event["tick"] if told == -1 else told
		if event["type"] == "hit" and event["attacker"] == BOSS and event["kind"] == "ranged":
			check(told != -1 and event["tick"] - told >= 3, "the tell came first, with time to react (told %d, hit %d)" % [told, event["tick"]])
			return
	check(false, "no thrown blow seen")


func test_ranged_stance_keeps_its_distance_and_resets() -> void:
	var fight := _fight(60)
	var sim: Simulation = fight["sim"]
	var boss: RefCounted = fight["boss"]
	var seen_reach: float = boss.reach
	check(sim.boss.stance(boss).has("kind"), "in a stance")
	# The player has gone; he's healed.
	sim.get_combatant(PLAYER).position = Vector3(0, 0, 200)
	boss.target_id = -1
	boss.hp = boss.max_hp
	sim.step()
	check(sim.boss.stance(boss).is_empty(), "out of the fight, healed: stances start over")
	check_eq(boss.reach, 1.5, "his own reach again (was %.1f)" % seen_reach)
	check_eq(boss.attack_type(), "melee", "and his own blow")


func test_protecting_from_the_stance_helps() -> void:
	var taken := []
	for protect in [false, true]:
		var sim := Simulation.new(9)
		var player := sim.add_player(PLAYER)
		player.max_hp = 5000
		player.hp = 5000
		player.auto_retaliate = false
		player.skills.xp["pietas"] = Skills.xp_for_level(50)
		var boss := sim.add_monster(BOSS, "hrodgar", Vector3(0, 0, 1))
		boss.target_id = PLAYER
		for i in 200:
			if protect:
				player.favour = 50.0
				var want := "minerva_shield" if boss.attack_type() == "melee" else "diana_veil"
				if not player.blessings.has(want):
					sim.queue_item_action(PLAYER, "bless", {"blessing": want})
			sim.step()
			sim.boss.strikes.clear()
		taken.append(5000 - player.hp)
	check(taken[1] < taken[0] * 0.6, "switching protection with his stance pays (%d vs %d)" % [taken[1], taken[0]])
