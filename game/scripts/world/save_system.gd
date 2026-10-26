extends Node
## Loads the player's save on start, autosaves on a timer and on quit, and
## asks a new player to choose an account mode.

const SaveGame := preload("res://scripts/sim/save_game.gd")

const MODES := [
	["standard", "Citizen-to-be", "The usual path. Trade at the forum market freely."],
	["solitarius", "Solitarius", "Self-sufficient. No market, no trading. You earn everything yourself.\nYou can leave this mode later, but never return to it."],
]

@export var driver: Node
@export var player_entity: Node
@export var save_path := "user://save.json"
## Playtests turn this off so they never touch a real save.
@export var enabled := true
@export var autosave_ticks := 100

var _dialog: CanvasLayer


func _ready() -> void:
	if not enabled:
		return
	if FileAccess.file_exists(save_path) and load_game():
		pass
	else:
		_show_mode_dialog()
	driver.ticked.connect(_on_ticked)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and enabled:
		save_game()


func save_game() -> void:
	var data := SaveGame.capture(driver.sim, player_entity.entity_id, int(Time.get_unix_time_from_system()))
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(SaveGame.to_json(data))


func load_game() -> bool:
	var data := SaveGame.from_json(FileAccess.get_file_as_string(save_path))
	var id: int = player_entity.entity_id
	if not SaveGame.restore(driver.sim, id, data, int(Time.get_unix_time_from_system())):
		push_warning("Save at %s could not be loaded; starting fresh." % save_path)
		return false
	var combatant: RefCounted = player_entity.combatant
	player_entity.body().global_position = combatant.position + Vector3(0, 0.1, 0)
	for type in ["inventory_changed", "equipment_changed", "bank_changed"]:
		driver.replay_event({"type": type, "id": id, "tick": driver.sim.tick})
	for patch in driver.sim.farming.patches.values():
		if patch["owner"] == id:
			driver.replay_event({"type": "patch_changed", "patch": patch["id"], "crop": patch["crop"], "stage": patch["stage"],
				"ready": driver.sim.farming.is_ready(patch), "tick": driver.sim.tick})
	if not combatant.pet.is_empty():
		driver.replay_event({"type": "pet_changed", "id": id, "pet": combatant.pet, "tick": driver.sim.tick})
	for hotspot_id in combatant.villa_furniture:
		driver.replay_event({"type": "furniture_built", "id": id, "hotspot": hotspot_id,
			"furniture": combatant.villa_furniture[hotspot_id], "tick": driver.sim.tick})
	var grave: Dictionary = driver.sim.grave_of(id)
	if not grave.is_empty():
		driver.replay_event({"type": "grave_add", "id": id, "grave": grave["id"], "position": grave["position"],
			"items": grave["items"], "expires_at": grave["expires_at"], "tick": driver.sim.tick})
	return true


func _on_ticked(tick: int) -> void:
	if tick % autosave_ticks == 0:
		save_game()


func _show_mode_dialog() -> void:
	get_tree().paused = true
	_dialog = CanvasLayer.new()
	_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_dialog)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.position -= Vector2(280, 160)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.08, 0.97)
	style.set_content_margin_all(20)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	_dialog.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Choose your path"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	var first: Button = null
	for mode in MODES:
		var button := Button.new()
		button.text = "%s\n%s" % [mode[1], mode[2]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(520, 90)
		button.pressed.connect(_choose_mode.bind(mode[0]))
		column.add_child(button)
		first = first if first else button
	first.grab_focus.call_deferred()


func _choose_mode(mode: String) -> void:
	player_entity.combatant.account_mode = mode
	_dialog.queue_free()
	get_tree().paused = false
	save_game()
