extends "res://tools/playtest/scenario.gd"
## Plays a little, saves through the real SaveSystem to a temp file, then
## loads a second copy of the scene from that file and checks the state.
## Then it breaks the save: the next load falls back to the backup and sets
## the broken file aside.

const PLAYER := 1
const SaveScene := preload("res://scenes/main.tscn")


func run() -> void:
	var path := OS.get_user_data_dir().path_join("playtest_save_%d.json" % Time.get_ticks_usec())
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	driver().sim.queue_item_action(PLAYER, "equip", {"slot": 0})
	await walk_to(Vector3(4, 0, 4), 0.5)
	await seconds(1.0)
	me.skills.add_xp("mining", 500.0)
	me.slayer_points = 4
	var save_system: Node = main.get_node("SaveSystem")
	save_system.save_path = path
	save_system.save_game()
	expect(FileAccess.file_exists(path), "save file written")

	var copy: Node = SaveScene.instantiate()
	copy.get_node("SaveSystem").enabled = false
	get_tree().root.add_child(copy)
	await get_tree().physics_frame
	var loader: Node = copy.get_node("SaveSystem")
	loader.save_path = path
	expect(loader.load_game(), "load succeeded")
	var loaded: RefCounted = copy.get_node("SimDriver").sim.get_combatant(PLAYER)
	expect(loaded.equipment.worn["weapon"] == "bronze_pugio", "weapon restored")
	expect(loaded.skills.level("mining") == me.skills.level("mining"), "mining restored")
	expect(loaded.slayer_points == 4, "points restored")
	expect(copy.get_node("Player").global_position.distance_to(player().global_position) < 0.5, "position restored")
	metric("save_bytes", FileAccess.get_file_as_string(path).length())

	save_system.save_game()
	expect(FileAccess.file_exists(path + ".bak"), "the previous save kept as a backup")
	var broken := FileAccess.open(path, FileAccess.WRITE)
	broken.store_string("{ not json")
	broken.close()
	var fresh: Node = SaveScene.instantiate()
	fresh.get_node("SaveSystem").enabled = false
	get_tree().root.add_child(fresh)
	await get_tree().physics_frame
	var recovering: Node = fresh.get_node("SaveSystem")
	recovering.save_path = path
	expect(recovering.load_or_recover(), "a broken save falls back to the backup")
	expect(fresh.get_node("SimDriver").sim.get_combatant(PLAYER).slayer_points == 4, "the backup's progress restored")
	expect(not FileAccess.file_exists(path), "the broken save was set aside")
	var aside := Array(DirAccess.get_files_at(OS.get_user_data_dir())).filter(func(f): return f.begins_with(path.get_file() + ".broken-"))
	expect(aside.size() == 1, "and kept, not overwritten")
	copy.queue_free()
	fresh.queue_free()
	for f in aside:
		DirAccess.remove_absolute(OS.get_user_data_dir().path_join(f))
	DirAccess.remove_absolute(path + ".bak")
