extends "res://tools/playtest/scenario.gd"
## M opens the world map: every region is on it, the player is placed in
## Castra Ferrea, and after the road to the coast, in Portus Salis. Esc
## closes it without opening the pause menu.


func run() -> void:
	await seconds(0.3)
	var map: Node = main.get_node("WorldMap")
	await press("world_map")
	expect(map.is_open(), "M opens the world map")
	var names: Array = map.regions().map(func(r): return r["name"])
	for name in ["Castra Ferrea", "Portus Salis", "Barrow of the Lemures", "Villa", "Beyond the Limes"]:
		expect(name in names, "%s is on the map (%s)" % [name, names])
	expect(map.region_at(player().global_position) == "Castra Ferrea", "you start in Castra Ferrea")
	await seconds(0.3)
	await shot("world_map")
	await press("ui_cancel")
	await seconds(0.1)
	expect(not map.is_open(), "Esc closes it")
	expect(not main.get_node("PauseMenu").is_open(), "without opening the pause menu")

	var road: Node3D = main.get_node("RoadToPortus")
	player()._arrive_through(road)
	await seconds(1.0)
	expect(map.region_at(player().global_position) == "Portus Salis", "the road leads to Portus Salis (%s)" % map.region_at(player().global_position))
