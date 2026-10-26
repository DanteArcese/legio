extends "res://tools/playtest/scenario.gd"
## K opens the skills panel: every skill with its level, and the focused
## skill's XP to the next level. It follows XP as it comes in, the D-pad
## moves between skills, and Esc closes it without opening the pause menu.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var panel: Node = main.get_node("SkillsUi")
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	await press("skills_panel")
	expect(panel.is_open(), "K opens the skills panel")
	expect(panel.button_text("fishing") == "Fishing  1", "lists Fishing (%s)" % panel.button_text("fishing"))
	expect(panel.button_text("vitality") == "Vitality  10", "Vitality starts at 10")
	expect("to level 2" in panel.detail_text(), "the first skill shows XP to the next level (%s)" % panel.detail_text())

	driver().sim.award_xp(me, "fishing", me.skills.xp_for_level(12) + 5.0, [])
	await seconds(1.0)
	expect(panel.button_text("fishing") == "Fishing  12", "follows XP drops (%s)" % panel.button_text("fishing"))

	await press("ui_right")
	expect(panel.detail_text().begins_with("Strength"), "D-pad right moves to Strength (%s)" % panel.detail_text())
	await shot("skills_panel")

	await press("ui_cancel")
	await seconds(0.1)
	expect(not panel.is_open(), "Esc closes it")
	expect(not main.get_node("PauseMenu").is_open(), "without opening the pause menu")
