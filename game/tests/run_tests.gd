extends SceneTree
## Minimal headless test runner.
## Usage: godot --headless --path game --script res://tests/run_tests.gd
## Runs every test_* method in res://tests/test_*.gd and exits non-zero on failure.

const TESTS_DIR := "res://tests"


func _initialize() -> void:
	var failed := 0
	var passed := 0
	for file in DirAccess.get_files_at(TESTS_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load(TESTS_DIR.path_join(file))
		if script == null or not script.can_instantiate():
			failed += 1
			printerr("FAIL %s: could not load (see errors above)" % file)
			continue
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var instance: Object = script.new()
			instance.call(name)
			if instance.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for failure in instance.failures:
					printerr("FAIL %s::%s: %s" % [file, name, failure])
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 or passed == 0 else 0)
