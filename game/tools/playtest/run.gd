extends SceneTree
## Playtest runner. See scripts/playtest.sh for usage.
## User args (after --): --scenario=<name> [--out=<dir>] [--scene=<res path>]
## [--save=<path>]  (enables saving to that path; off by default)

const Bindings := preload("res://scripts/input/bindings.gd")
## Give up on a scenario that hangs (for example after a script error).
const WATCHDOG_SECONDS := 900

var _deadline_msec := 0
var _errors := ErrorCapture.new()


## Collects engine and script errors raised while a scenario runs, so a
## scenario that crashes part-way through fails instead of quietly passing.
class ErrorCapture extends Logger:
	var errors: PackedStringArray = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		# Headless runs use Godot's dummy renderer, which reports harmless
		# errors for material overrides that the real renderer handles fine.
		if file.begins_with("servers/rendering/dummy/"):
			return
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s:%d %s" % [file, line, rationale if not rationale.is_empty() else code])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	_deadline_msec = Time.get_ticks_msec() + WATCHDOG_SECONDS * 1000
	OS.add_logger(_errors)
	var args := _parse_args()
	var scenario_name: String = args.get("scenario", "")
	if scenario_name.is_empty():
		printerr("Missing --scenario=<name>")
		quit(2)
		return
	Bindings.apply()
	var main: Node = load(args.get("scene", "res://scenes/main.tscn")).instantiate()
	# Never read or write the real save, and skip the new-character dialog.
	var save_system: Node = main.get_node_or_null("SaveSystem")
	if save_system:
		save_system.enabled = args.get("save", "") != ""
		if save_system.enabled:
			save_system.save_path = args["save"]
	# Playtests run at a fixed midday unless a scenario changes it.
	var day_night: Node = main.get_node_or_null("DayNight")
	if day_night:
		day_night.running = false
		day_night.hour = 12.0
	var graphics: Node = main.get_node_or_null("GraphicsSettings")
	if graphics:
		graphics.persist = false
	var sound: Node = main.get_node_or_null("Sound")
	if sound:
		sound.persist = false
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
	for error in _errors.errors:
		scenario.failures.append("engine/script error: " + error)
	var result := {"scenario": scenario_name, "metrics": scenario.metrics, "failures": scenario.failures}
	print(JSON.stringify(result, "  "))
	if not scenario.out_dir.is_empty():
		var file := FileAccess.open(scenario.out_dir.path_join("result.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "  "))
	quit(1 if scenario.failures.size() > 0 else 0)


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > _deadline_msec:
		printerr("Playtest timed out after %d s (a script error can cause this; check the log above)." % WATCHDOG_SECONDS)
		quit(3)
	return false


func _parse_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var parts := arg.substr(2).split("=", true, 1)
			args[parts[0]] = parts[1]
	return args
