extends CanvasLayer
## Player HUD: hitpoints, combat style and levels, XP drops, and level-up banners.

const Slayer := preload("res://scripts/sim/slayer.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")
const Quests := preload("res://scripts/sim/quests.gd")

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
## Shown while the player is beyond the Limes, where deaths are costly.
var _danger: Label


func _ready() -> void:
	_status = _label(24, HORIZONTAL_ALIGNMENT_LEFT)
	_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_status.position = Vector2(24, -100)
	_status.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# A translucent backing keeps the text readable over world signs and labels.
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0, 0, 0, 0.55)
	backing.set_corner_radius_all(6)
	backing.set_content_margin_all(8)
	_status.add_theme_stylebox_override("normal", backing)
	add_child(_status)

	_drops = VBoxContainer.new()
	_drops.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	# Below the minimap.
	_drops.position = Vector2(-280, 270)
	_drops.custom_minimum_size = Vector2(260, 0)
	add_child(_drops)

	_banner = _label(36, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.position.y = 90
	_banner.modulate.a = 0.0
	add_child(_banner)

	_danger = _label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_danger.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_danger.position.y = 40
	_danger.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25))
	_danger.text = "Beyond the Limes: no graves here"
	_danger.visible = false
	add_child(_danger)

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
		"quest_complete":
			_show_banner("Quest complete: %s" % ContentDB.quest(event["quest"])["name"])
		"death":
			_show_banner("You have fallen.")


func _refresh() -> void:
	var c: RefCounted = player_entity.combatant
	if c == null:
		return
	var s: RefCounted = c.skills
	_refresh_target(c)
	var beyond: bool = driver.sim.in_danger_zone(c.position)
	if beyond != _danger.visible:
		_danger.visible = beyond
		_show_banner("You cross the Limes." if beyond else "You are back inside the Limes.")
	var task_text := "No Slayer contract"
	if not c.slayer_task.is_empty():
		task_text = "Contract: %d %s left" % [c.slayer_task["remaining"], Slayer.plural_name(c.slayer_task["monster"])]
	if not c.arena_contract.is_empty():
		var beast: String = ContentDB.data()["arena"]["contracts"][c.arena_contract["id"]]["monster"]
		task_text += "   Arena: %s" % ("hand in to Marcia" if c.arena_contract["remaining"] == 0 else "net %d %s" % [c.arena_contract["remaining"], Slayer.plural_name(beast)])
	if c.rested_until > driver.sim.tick:
		task_text += "   Rested (%d min)" % ceili((c.rested_until - driver.sim.tick) * 0.6 / 60.0)
	if c.pollution > 0.0:
		task_text += "   Pollution %d%s" % [ceili(c.pollution), " (polluted)" if c.pollution >= 30.0 else ""]
	var title := Quests.title(c)
	if not title.is_empty():
		task_text = "%s   %s" % [title, task_text]
	if c.account_mode == "solitarius":
		task_text = "[Solitarius]  " + task_text
	elif c.account_mode == "hardcore":
		task_text = "[Hardcore Solitarius]  " + task_text
	var ammo_text := ""
	if c.uses_ammo():
		var ammo: String = c.equipment.worn["ammo"]
		ammo_text = "     Ammo: %s" % ("none" if ammo.is_empty() else "%s x%d" % [ContentDB.item(ammo)["name"], c.equipment.ammo_count])
	var special: Dictionary = c.equipment.weapon().get("special", {})
	if not special.is_empty():
		ammo_text += "   Impetus %d%s" % [c.impetus, "  [%s ready]" % special["name"] if c.special_armed else " (F / B)"]
	_status.text = "%s   (Slayer points: %d)\nHP %d / %d     Style: %s (C / X)%s   Favour %d / %d\nCombat %d   Atk %s   Str %s   Def %s   Rng %s   Rit %s   Pie %d   Vit %d   Slay %d" % [
		task_text, c.slayer_points, c.hp, c.max_hp, c.style.capitalize(), ammo_text, ceili(c.favour), s.level("pietas"), s.combat_level(),
		_with_boost(c, "attack"), _with_boost(c, "strength"), _with_boost(c, "defence"), _with_boost(c, "ranged"), _with_boost(c, "ritus"),
		s.level("pietas"), s.level("vitality"), s.level("slayer")]


## A level with any remedy boost or drain shown, e.g. "12+3" or "12-2".
static func _with_boost(c: RefCounted, skill: String) -> String:
	var boost: int = c.remedy_boost(skill)
	if boost == 0:
		return str(c.level(skill))
	return "%d%+d" % [c.level(skill), boost]


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
	var afflictions := PackedStringArray()
	if target.is_bound(driver.sim.tick):
		afflictions.append("bound")
	if target.curses.has("withering"):
		afflictions.append("withering")
	if not afflictions.is_empty():
		_target_name.text += "  [%s]" % ", ".join(afflictions)
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
