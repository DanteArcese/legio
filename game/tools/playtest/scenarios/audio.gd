extends "res://tools/playtest/scenario.gd"
## Sound follows play: town ambience inside the walls, steps on stone and
## grass, combat sounds on the training dummy, and the woods' ambience
## outside. The pause menu's Effects slider changes its bus.


func run() -> void:
	var sound: Node = main.get_node("Sound")
	await seconds(0.5)
	expect(sound.zone == "town", "town ambience inside the walls (got %s)" % sound.zone)

	await press("interact")
	await seconds(12.0)
	expect(sound.played.get("step_stone", 0) > 0, "steps on the fort's paving")
	expect(sound.played.get("swing", 0) > 0, "attacks swing")
	expect(sound.played.get("hit", 0) + sound.played.get("block", 0) > 0, "attacks hit or are blocked")

	driver().sim.queue_stop(1)
	await route_to(Vector3(0, 0, -30), 1.5, 90.0)
	await seconds(0.5)
	expect(sound.zone == "day", "woods ambience outside (got %s)" % sound.zone)
	expect(sound.played.get("step_grass", 0) > 0, "steps on grass")
	metric("sounds", sound.played)

	var effects := AudioServer.get_bus_index("Effects")
	expect(effects != -1 and AudioServer.get_bus_index("Ambient") != -1, "effects and ambient buses exist")
	await press("pause_menu")
	await seconds(0.1)
	var slider: HSlider = main.get_node("PauseMenu").find_child("EffectsVolume", true, false)
	expect(slider != null, "the pause menu has an Effects slider")
	if slider:
		var before := AudioServer.get_bus_volume_db(effects)
		slider.grab_focus()
		await press("ui_left")
		await press("ui_left")
		expect(AudioServer.get_bus_volume_db(effects) < before, "lowering the slider quietens effects")
	await press("pause_menu")
