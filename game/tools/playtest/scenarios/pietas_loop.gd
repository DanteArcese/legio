extends "res://tools/playtest/scenario.gd"
## The Pietas loop: buy incense from the sacerdos, offer bones and incense at
## the heavenly altar, turn on a blessing from the panel with the
## controller, spend favour in a fight, and pray to restore it.

const PLAYER := 1


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	var ui: Node = main.get_node("GameUi")
	driver().sim.give_item(PLAYER, "coins", 100, "test", [])
	driver().sim.give_item(PLAYER, "bones", 10, "test", [])
	player().buy(main.get_node("Sacerdos"), "incense")
	await _wait_until(func(): return me.inventory.count("incense") == 5, 20.0)
	expect(me.inventory.count("incense") == 5, "bought incense")

	var altar: Node3D = main.get_node("Altars/HeavenlyAltar")
	player().offer(altar, "bones")
	await _wait_until(func(): return me.inventory.count("bones") == 0, 60.0)
	player().offer(altar, "incense")
	await _wait_until(func(): return me.inventory.count("incense") == 0, 60.0)
	metric("pietas_xp", int(me.skills.xp["pietas"]))
	metric("pietas_level", me.skills.level("pietas"))
	expect(me.skills.xp["pietas"] == 125.0, "10 bones and 5 incense give 125 XP")

	# Turn on Vigour of Mars from the panel: P, then A on the first blessing.
	await press("pietas_menu")
	await seconds(0.1)
	expect(ui.is_blessings_open(), "P opens the blessings panel")
	await shot("blessings_panel")
	await press("ui_accept")
	await seconds(0.5)
	expect(me.blessings.has("mars_vigour"), "A turns on Vigour of Mars")
	await press("pietas_menu")

	# Spend favour, then pray it back.
	var start_favour: float = me.favour
	await seconds(15.0)
	expect(me.favour < start_favour, "favour drains while blessed (%.1f -> %.1f)" % [start_favour, me.favour])
	player().pray(altar)
	await _wait_until(func(): return me.favour >= float(me.skills.level("pietas")), 10.0)
	expect(me.favour >= float(me.skills.level("pietas")), "praying restores favour")


func _wait_until(condition: Callable, timeout: float) -> void:
	for i in ceili(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return
		await get_tree().physics_frame
