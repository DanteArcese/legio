extends "res://tools/playtest/scenario.gd"
## Esc / Start opens the pause menu, which pauses the game; the graphics
## preset cycles Low -> Medium -> High; Hide roofs toggles; Resume unpauses.

func run() -> void:
	await seconds(0.3)
	var menu: Node = main.get_node("PauseMenu")
	var settings: Node = main.get_node("GraphicsSettings")
	var env: Environment = main.get_node("WorldEnvironment").environment
	expect(settings.preset == "medium", "defaults to Medium")
	expect(env.ssao_enabled, "Medium has ambient occlusion")
	await shot("medium")
	await press("pause_menu")
	await _frames(3)
	expect(menu.is_open() and get_tree().paused, "Esc pauses and opens the menu")
	await shot("menu")
	await press("ui_down")
	await press("ui_accept")
	await _frames(3)
	expect(settings.preset == "high" and env.glow_enabled, "Graphics -> High")
	await press("ui_accept")
	await _frames(3)
	expect(settings.preset == "low" and not env.ssao_enabled, "Graphics -> Low")
	await press("ui_down")
	await press("ui_accept")
	await _frames(3)
	expect(settings.hide_roofs(), "Hide roofs on")
	await press("ui_up")
	await press("ui_up")
	await press("ui_accept")
	await _frames(3)
	expect(not menu.is_open() and not get_tree().paused, "Resume unpauses")
	await seconds(0.3)
	await shot("low_roofs_hidden")


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
