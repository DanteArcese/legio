extends "res://tools/playtest/scenario.gd"
## The pause menu's Controls page lists every action with both bindings;
## Esc goes back to the menu.

func run() -> void:
	await seconds(0.3)
	var menu: Node = main.get_node("PauseMenu")
	menu.open()
	await get_tree().process_frame
	menu.show_controls()
	await seconds(0.2)
	expect(menu.is_controls_open(), "the controls page opens")
	await shot("controls")
	await press("pause_menu")
	await get_tree().process_frame
	expect(not menu.is_controls_open() and menu.is_open(), "Esc goes back to the menu")
	menu.close()
