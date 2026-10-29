extends "res://tests/test_case.gd"
## Saves are swapped in atomically, keeping the previous save as a backup.

const SaveSystem := preload("res://scripts/world/save_system.gd")


func _path() -> String:
	return "user://test_safe_save_%d.json" % Time.get_ticks_usec()


func _cleanup(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func test_a_save_keeps_the_previous_one_as_a_backup() -> void:
	var path := _path()
	check(SaveSystem.write_atomically(path, "first"), "first write")
	check_eq(FileAccess.get_file_as_string(path), "first", "written")
	check(not FileAccess.file_exists(path + ".bak"), "no backup yet")
	check(SaveSystem.write_atomically(path, "second"), "second write")
	check_eq(FileAccess.get_file_as_string(path), "second", "replaced")
	check_eq(FileAccess.get_file_as_string(path + ".bak"), "first", "the old save kept")
	SaveSystem.write_atomically(path, "third")
	check_eq(FileAccess.get_file_as_string(path + ".bak"), "second", "the backup rolls forward")
	check(not FileAccess.file_exists(path + ".tmp"), "no temp file left behind")
	_cleanup(path)
