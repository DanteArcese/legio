extends "res://tools/playtest/scenario.gd"
## Trains on the dummy for 10 minutes of game time on each style and
## reports XP rates, to sanity-check the curve and XP-per-damage numbers.


func run() -> void:
	var player_id := 1
	var skills: RefCounted = main.get_node("Player/SimEntity").combatant.skills
	for style in ["accurate", "aggressive", "defensive"]:
		driver().sim.queue_style(player_id, style)
		var start: int = driver().sim.tick
		var deadline: int = start + 1000 # 10 minutes at 0.6 s ticks
		while driver().sim.tick < deadline:
			if driver().sim.get_combatant(player_id).target_id == -1:
				driver().sim.queue_attack(player_id, 100)
			await seconds(0.5)
		await shot("after_%s" % style)
	for skill in ["attack", "strength", "defence", "vitality"]:
		metric("%s_level" % skill, skills.level(skill))
		metric("%s_xp" % skill, int(skills.xp[skill]))
	metric("combat_level", skills.combat_level())
	metric("level_ups", count_events("level_up", {"id": player_id}))
	expect(skills.level("attack") >= 5, "10 min accurate should reach attack 5+")
	expect(skills.level("strength") >= 5, "10 min aggressive should reach strength 5+")
	expect(skills.level("defence") >= 5, "10 min defensive should reach defence 5+")
