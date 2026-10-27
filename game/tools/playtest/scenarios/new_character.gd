extends "res://tools/playtest/scenario.gd"
## The new-character dialog: it pauses the game, the D-pad moves between
## the three modes, and A picks one.

const PLAYER := 1


func run() -> void:
	var save_system: Node = main.get_node("SaveSystem")
	var path := OS.get_user_data_dir().path_join("playtest_new_%d.json" % Time.get_ticks_usec())
	save_system.save_path = path
	save_system._show_mode_dialog()
	await get_tree().process_frame
	expect(get_tree().paused, "game paused while choosing")
	var tick_before: int = driver().sim.tick
	await seconds(1.0)
	expect(driver().sim.tick == tick_before, "simulation doesn't advance while paused")
	await shot("dialog")
	await press("ui_down")
	await press("ui_accept")
	for i in 10:
		await get_tree().process_frame
	expect(not get_tree().paused, "unpaused after choosing")
	expect(driver().sim.get_combatant(PLAYER).account_mode == "solitarius", "D-pad down + A chose Solitarius")
	expect(FileAccess.file_exists(path), "saved right away")
	DirAccess.remove_absolute(path)
