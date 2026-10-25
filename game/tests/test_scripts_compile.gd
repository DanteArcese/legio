extends "res://tests/test_case.gd"
## Every game and tool script must compile. A script that fails to parse
## otherwise only shows up as a silent hang or a missing feature at runtime.

const ROOTS := ["res://scripts", "res://tools"]


func test_every_script_compiles() -> void:
	var count := 0
	for root in ROOTS:
		for path in _scripts_under(root):
			var script: Script = load(path)
			check(script != null and script.can_instantiate(), "%s compiles" % path)
			count += 1
	check(count > 40, "found the scripts (%d)" % count)


func _scripts_under(dir_path: String) -> Array:
	var found := []
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_scripts_under(dir_path.path_join(sub)))
	return found
