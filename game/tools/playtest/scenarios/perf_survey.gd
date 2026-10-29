extends "res://tools/playtest/scenario.gd"
## Stands in each region for a few seconds and reports what a frame costs
## there: script and physics time, and (with --render) draw calls, objects
## and primitives, plus the node count. Informational: it fails only on
## errors. docs/performance.md records a run.

const SPOTS := {
	"fort_forum": Vector3(0, 1, 6),
	"fort_fields": Vector3(0, 1, 40),
	"grove": Vector3(-40, 1, 0),
	"portus_salis": Vector3(-300, 1, -8),
	"frontier_camp": Vector3(0, 1, -420),
	"vipasca": Vector3(0, 1, 380),
	"seriphos_town": Vector3(-300, 1, 300),
	"circus": Vector3(320, 1, 160),
	"villa": Vector3(320, 1, 8),
}
const SAMPLE_FRAMES := 30


func run() -> void:
	await seconds(1.0)
	for name in SPOTS:
		player().destination = null
		player().global_position = SPOTS[name]
		await seconds(2.0)
		var totals := {"process": 0.0, "physics": 0.0, "draws": 0.0, "objects": 0.0, "primitives": 0.0}
		for i in SAMPLE_FRAMES:
			await get_tree().process_frame
			totals["process"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			totals["physics"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			totals["draws"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			totals["objects"] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
			totals["primitives"] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var line := {}
		for key in totals:
			line[key] = snappedf(totals[key] / SAMPLE_FRAMES, 0.1)
		line["nodes"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		metric(name, line)
		print("[perf] %s %s" % [name, line])
		await shot(name)
