extends CanvasLayer
## Player HUD: hitpoints, combat style and levels, XP drops, and level-up banners.

const Slayer := preload("res://scripts/sim/slayer.gd")

const DROP_DURATION := 1.6
const BANNER_DURATION := 3.0

@export var driver: Node
@export var player_entity: Node

var _status: Label
var _drops: VBoxContainer
var _banner: Label
var _target_panel: PanelContainer
var _target_name: Label
var _target_bar: ProgressBar


func _ready() -> void:
	_status = _label(24, HORIZONTAL_ALIGNMENT_LEFT)
	_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_status.position = Vector2(24, -100)
	_status.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_status)

	_drops = VBoxContainer.new()
	_drops.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_drops.position = Vector2(-280, 60)
	_drops.custom_minimum_size = Vector2(260, 0)
	add_child(_drops)

	_banner = _label(36, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.position.y = 90
	_banner.modulate.a = 0.0
	add_child(_banner)

	_build_target_panel()
	driver.sim_event.connect(_on_sim_event)
	driver.ticked.connect(func(_tick): _refresh())
	_refresh.call_deferred()


func _on_sim_event(event: Dictionary) -> void:
	if event.get("id") != player_entity.entity_id:
		return
	match event["type"]:
		"xp":
			_xp_drop(event["skill"], event["amount"])
		"level_up":
			_show_banner("%s level %d!" % [event["skill"].capitalize(), event["level"]])
		"death":
			_show_banner("You have fallen.")


func _refresh() -> void:
	var c: RefCounted = player_entity.combatant
	if c == null:
		return
	var s: RefCounted = c.skills
	_refresh_target(c)
	var task_text := "No Slayer contract"
	if not c.slayer_task.is_empty():
		task_text = "Contract: %d %s left" % [c.slayer_task["remaining"], Slayer.plural_name(c.slayer_task["monster"])]
	if c.account_mode == "solitarius":
		task_text = "[Solitarius]  " + task_text
	_status.text = "%s   (Slayer points: %d)\nHP %d / %d     Style: %s (C / X)\nCombat %d   Atk %d   Str %d   Def %d   Vit %d   Slay %d" % [
		task_text, c.slayer_points, c.hp, c.max_hp, c.style.capitalize(), s.combat_level(),
		s.level("attack"), s.level("strength"), s.level("defence"), s.level("vitality"), s.level("slayer")]


## Top-centre panel naming the current target with an HP bar.
func _build_target_panel() -> void:
	_target_panel = PanelContainer.new()
	_target_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_target_panel.custom_minimum_size = Vector2(300, 0)
	_target_panel.position = Vector2(-150, 14)
	var column := VBoxContainer.new()
	_target_panel.add_child(column)
	_target_name = _label(20, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_target_name)
	_target_bar = ProgressBar.new()
	_target_bar.custom_minimum_size = Vector2(280, 18)
	_target_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.7, 0.25)
	_target_bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.6, 0.12, 0.1)
	_target_bar.add_theme_stylebox_override("background", background)
	column.add_child(_target_bar)
	_target_panel.visible = false
	add_child(_target_panel)


func _refresh_target(c: RefCounted) -> void:
	var target: RefCounted = driver.sim.get_combatant(c.target_id)
	_target_panel.visible = target != null and target.is_alive()
	if not _target_panel.visible:
		return
	var entity: Node = driver.entity(target.id)
	var name: String = entity.display_name() if entity else "?"
	_target_name.text = "%s (level %d)" % [name, target.combat_level()] if not target.monster_id.is_empty() else name
	_target_bar.max_value = target.max_hp
	_target_bar.value = target.hp


func _xp_drop(skill: String, amount: float) -> void:
	var drop := _label(22, HORIZONTAL_ALIGNMENT_RIGHT)
	drop.text = "+%s %s" % [_format_xp(amount), skill.capitalize()]
	_drops.add_child(drop)
	var tween := drop.create_tween()
	tween.tween_property(drop, "modulate:a", 0.0, DROP_DURATION).set_delay(DROP_DURATION * 0.5)
	tween.tween_callback(drop.queue_free)


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	var tween := _banner.create_tween()
	tween.tween_property(_banner, "modulate:a", 0.0, 0.8).set_delay(BANNER_DURATION)


func _label(size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label


static func _format_xp(amount: float) -> String:
	return str(int(amount)) if amount == floorf(amount) else "%.1f" % amount
