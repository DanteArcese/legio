extends "res://tools/playtest/scenario.gd"
## The music follows the player: the fort's lyre in Castra Ferrea, the
## harbour's style at Portus Salis, the aulos and a drone beyond the Limes,
## and the open road between. Notes actually play, on the Music bus.

func run() -> void:
	var music: Node = main.get_node("Music")
	await seconds(1.0)
	expect(music.style == "fort", "the fort's music in Castra Ferrea (%s)" % music.style)
	await seconds(8.0)
	expect(music.played.get("lyre", 0) > 0, "the lyre plays (%s)" % music.played)
	expect(AudioServer.get_bus_index("Music") != -1, "there's a Music bus")

	_move(Vector3(-300, 1, -8))
	await seconds(1.0)
	expect(music.style == "coast", "the harbour's music at Portus Salis (%s)" % music.style)

	_move(Vector3(0, 1, -420))
	await seconds(1.0)
	expect(music.style == "frontier", "the frontier's music beyond the Limes (%s)" % music.style)
	await seconds(12.0)
	expect(music.played.get("aulos", 0) > 0, "the aulos plays out there (%s; t %.1f, end %.1f, silence %.1f, queued %d)" % [music.played, music._time, music._phrase_end, music._silence_end, music._queue.size()])
	expect(music._drone.playing, "under a drone")

	_move(Vector3(0, 1, -150))
	await seconds(1.0)
	expect(music.style == "roads", "the road music between places (%s)" % music.style)


func _move(to: Vector3) -> void:
	player().destination = null
	player().global_position = to
