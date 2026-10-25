extends "res://tools/playtest/scenario.gd"
## The day/night cycle: noon is bright, midnight is dark with lamps lit and
## a moon, dawn and dusk are warm, and the dungeon ignores the sky.

func run() -> void:
	await seconds(0.3)
	var cycle: Node = main.get_node("DayNight")
	var sun: DirectionalLight3D = main.get_node("Sun")
	var lamp: OmniLight3D = main.get_node("Lamps/Lamp5").find_children("*", "OmniLight3D", true, false)[0]
	player().global_position = Vector3(0, 1, 2)
	var energies := {}
	for hour in [12.0, 18.6, 0.0, 6.6]:
		cycle.hour = hour
		await seconds(0.3)
		energies[hour] = sun.light_energy
		await shot("hour_%02d" % int(hour))
		if hour == 0.0:
			expect(cycle.is_night(), "midnight is night")
			expect(lamp.visible and lamp.light_energy > 1.0, "lamps lit at night")
			expect(main.get_node("Moon").visible, "the moon is up")
	expect(energies[12.0] > 1.0, "noon is bright")
	expect(energies[0.0] < 0.05, "no sun at midnight")
	expect(energies[18.6] < energies[12.0] and energies[18.6] > 0.0, "dusk is dimmer than noon")
	cycle.hour = 12.0
	await seconds(0.3)
	expect(not lamp.visible, "lamps off at noon")

	# Underground the cycle stays out of the way.
	cycle.hour = 0.0
	player().global_position = Vector3(150, 1, 2.5)
	await seconds(0.5)
	expect(not lamp.visible, "town lamps aren't drawn while underground")
	expect(main.get_node("AreaLighting").underground, "underground")

	# Time actually passes when running.
	cycle.running = true
	cycle.cycle_minutes = 1.0
	var before: float = cycle.hour
	await seconds(2.5)
	expect(cycle.hour > before + 0.5, "time moves (%.2f -> %.2f)" % [before, cycle.hour])
