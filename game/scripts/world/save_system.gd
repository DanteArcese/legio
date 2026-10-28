extends Node
## Loads the player's save on start, autosaves on a timer and on quit, and
## asks a new player to choose an account mode. Saves are written to a temp
## file and swapped in, keeping the previous one as a backup; a save that
## won't load falls back to the backup, and is set aside rather than
## overwritten if neither will.

const SaveGame := preload("res://scripts/sim/save_game.gd")

const MODES := [
	["standard", "Citizen-to-be", "The usual path. You'll be free to trade with others when there's someone to trade with."],
	["solitarius", "Solitarius", "Self-sufficient. You'll never trade with other players or a market; shops and everything else work as usual.\nYou can give it up later from the pause menu, but never return to it."],
	["hardcore", "Hardcore Solitarius", "A Solitarius with one life. Your first death makes you a plain Solitarius, for good."],
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
	if not load_or_recover():
		_show_mode_dialog()
	driver.ticked.connect(_on_ticked)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and enabled:
		save_game()


func save_game() -> void:
	var data := SaveGame.capture(driver.sim, player_entity.entity_id, int(Time.get_unix_time_from_system()))
	write_atomically(save_path, SaveGame.to_json(data))


## Loads the save, or its backup if the save won't load (setting the broken
## one aside). False when there's nothing to load: a new character.
func load_or_recover() -> bool:
	var loaded := FileAccess.file_exists(save_path) and load_game(save_path)
	if not loaded and FileAccess.file_exists(save_path):
		_set_aside(save_path)
	if not loaded and FileAccess.file_exists(backup_path()):
		loaded = load_game(backup_path())
	return loaded


func backup_path() -> String:
	return save_path + ".bak"


## Writes text to a temp file, then swaps it in for path, keeping what was
## there as path.bak. A crash mid-write leaves the old save untouched.
static func write_atomically(path: String, text: String) -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var backup := absolute + ".bak"
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(backup)
		DirAccess.rename_absolute(absolute, backup)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), absolute) == OK


## Moves an unreadable save out of the way so a fresh start can't overwrite it.
static func _set_aside(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	var aside := "%s.broken-%d" % [absolute, int(Time.get_unix_time_from_system())]
	DirAccess.rename_absolute(absolute, aside)
	push_warning("Save at %s could not be loaded; kept it as %s." % [path, aside])


func load_game(path := "") -> bool:
	if path.is_empty():
		path = save_path
	var data := SaveGame.from_json(FileAccess.get_file_as_string(path))
	var id: int = player_entity.entity_id
	if data.is_empty() or not SaveGame.restore(driver.sim, id, data, int(Time.get_unix_time_from_system())):
		push_warning("Save at %s could not be loaded." % path)
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
	# Above the HUD and the other overlays.
	_dialog.layer = 50
	_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_dialog)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.08, 0.97)
	style.set_content_margin_all(20)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
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
