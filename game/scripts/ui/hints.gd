extends CanvasLayer
## First-time hints: a short tip the first time something becomes useful
## (a weapon special, region tasks, the Tabularium, a full pack...), each
## shown once per machine and remembered in user://hints.cfg.

const HINTS_PATH := "user://hints.cfg"
const SHOW_SECONDS := 9.0
const TEXT := {
	"controls": "Tip: Esc (Start) opens the pause menu, with every control listed under Controls.",
	"special": "Tip: this weapon has a special attack. F (B) readies it for your next blow; it spends impetus, which refills over time.",
	"tasks": "Tip: region tasks are listed in the quest log (J / D-pad right). Finish a region's list to be paid.",
	"tabularium": "Tip: the Tabularium (L / right trigger) records the notable things you've found.",
	"bank": "Tip: your pack is full. Bank chests keep everything, and your bank is shared across the province.",
	"slayer": "Tip: the HUD tracks your contract. Slayer points buy cancels, blocks and unlocks from the venator's menu.",
}

@export var driver: Node
@export var player: Node3D
## Off in playtests, so they neither read nor write the real hints file.
@export var persist := true

var seen := {}
var _queue: Array[String] = []
var _panel: PanelContainer
var _label: Label
var _timer := 0.0


func _ready() -> void:
	_build()
	if persist:
		var config := ConfigFile.new()
		if config.load(HINTS_PATH) == OK:
			for key in config.get_section_keys("seen") if config.has_section("seen") else []:
				seen[key] = true
	if driver:
		driver.sim_event.connect(_on_sim_event)
	get_tree().create_timer(3.0).timeout.connect(func(): hint("controls"))


func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			_panel.visible = false
	if _timer <= 0.0 and not _queue.is_empty():
		_label.text = TEXT[_queue.pop_front()]
		_panel.visible = true
		_timer = SHOW_SECONDS


## Shows a hint unless it's been seen, and remembers it.
func hint(id: String) -> void:
	if seen.has(id) or _queue.has(id):
		return
	seen[id] = true
	_queue.append(id)
	if persist:
		var config := ConfigFile.new()
		config.load(HINTS_PATH)
		config.set_value("seen", id, true)
		config.save(HINTS_PATH)


func is_showing() -> bool:
	return _panel.visible


func shown_text() -> String:
	return _label.text


func _on_sim_event(event: Dictionary) -> void:
	if player == null or not player.has_node("SimEntity"):
		return
	var me: int = player.get_node("SimEntity").entity_id
	var combatant: RefCounted = player.get_node("SimEntity").combatant
	match event["type"]:
		"hit":
			if event["attacker"] == me and combatant and not combatant.equipment.weapon().get("special", {}).is_empty():
				hint("special")
		"task_done":
			if event["id"] == me:
				hint("tasks")
		"collection_new":
			if event["id"] == me:
				hint("tabularium")
		"slayer_assigned":
			if event["id"] == me:
				hint("slayer")
		"inventory_changed":
			if event["id"] == me and combatant and combatant.inventory.slots.all(func(s): return s != null):
				hint("bank")


## A gold-edged card under the minimap.
func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.position += Vector2(-440, 270)
	_panel.custom_minimum_size = Vector2(420, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.92)
	style.border_color = Color(0.75, 0.6, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(396, 0)
	_label.add_theme_font_size_override("font_size", 18)
	_panel.add_child(_label)
	_panel.visible = false
