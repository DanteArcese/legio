extends SceneTree
## Playtest runner. See scripts/playtest.sh for usage.
## User args (after --): --scenario=<name> [--out=<dir>] [--scene=<res path>]

const Bindings := preload("res://scripts/input/bindings.gd")


func _initialize() -> void:
	var args := _parse_args()
	var scenario_name: String = args.get("scenario", "")
	if scenario_name.is_empty():
		printerr("Missing --scenario=<name>")
		quit(2)
		return
	Bindings.apply()
	var main: Node = load(args.get("scene", "res://scenes/main.tscn")).instantiate()
	root.add_child(main)

	var script: GDScript = load("res://tools/playtest/scenarios/%s.gd" % scenario_name)
	if script == null or not script.can_instantiate():
		printerr("Could not load scenario '%s'" % scenario_name)
		quit(2)
		return
	var scenario: Node = script.new()
	scenario.main = main
	scenario.out_dir = args.get("out", "")
	if not scenario.out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(scenario.out_dir)
	main.get_node("SimDriver").sim_event.connect(func(event): scenario.events.append(event))
	root.add_child(scenario)
	_run(scenario, scenario_name)


func _run(scenario: Node, scenario_name: String) -> void:
	await process_frame
	await scenario.run()
	var result := {"scenario": scenario_name, "metrics": scenario.metrics, "failures": scenario.failures}
	print(JSON.stringify(result, "  "))
	if not scenario.out_dir.is_empty():
		var file := FileAccess.open(scenario.out_dir.path_join("result.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "  "))
	quit(1 if scenario.failures.size() > 0 else 0)


func _parse_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var parts := arg.substr(2).split("=", true, 1)
			args[parts[0]] = parts[1]
	return args
