extends CanvasLayer
## The world map (M): every region in the map_regions group drawn where it
## lies, with roads and doorways between them as dashed links, danger zones
## tinted red, and the player as a marker. Regions are scene nodes with
## map_name and map_rect (an XZ Rect2) metadata, and optionally map_color,
## so new ones add themselves.

const Quests := preload("res://scripts/sim/quests.gd")
const QUEST_MARK := Color(0.85, 0.6, 0.05)
const PANEL_SIZE := Vector2(900, 620)
const MARGIN := 40.0
const PARCHMENT := Color(0.86, 0.8, 0.66)
const INK := Color(0.3, 0.22, 0.14)
const LAND := Color(0.62, 0.7, 0.48)
const DANGER := Color(0.8, 0.25, 0.2, 0.45)
const LINK := Color(0.45, 0.3, 0.18)
const PLAYER_MARK := Color(0.85, 0.1, 0.1)

@export var player: Node3D

var _panel: Control
var _canvas: Control
var _regions: Array[Dictionary] = []


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.position -= PANEL_SIZE / 2.0
	var style := StyleBoxFlat.new()
	style.bg_color = PARCHMENT
	style.border_color = INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_canvas = Control.new()
	_canvas.custom_minimum_size = PANEL_SIZE
	_canvas.draw.connect(_draw_map)
	_panel.add_child(_canvas)
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("world_map"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_regions = regions()
		_canvas.queue_redraw()


func _process(_delta: float) -> void:
	if _panel.visible:
		_canvas.queue_redraw()


## Every region on the map: {"name", "rect", "color"}.
func regions() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("map_regions"):
		found.append({"name": node.get_meta("map_name"), "rect": node.get_meta("map_rect"), "color": node.get_meta("map_color", LAND)})
	return found


## The name of the region containing a world position, or "".
func region_at(position: Vector3) -> String:
	for region in regions():
		if region["rect"].has_point(Vector2(position.x, position.z)):
			return region["name"]
	return ""


## Maps world XZ into the canvas, fitting all regions with a margin.
func _transform() -> Transform2D:
	var bounds: Rect2 = _regions[0]["rect"]
	for region in _regions:
		bounds = bounds.merge(region["rect"])
	var scale := minf((PANEL_SIZE.x - MARGIN * 2.0) / bounds.size.x, (PANEL_SIZE.y - MARGIN * 2.0) / bounds.size.y)
	var offset := (PANEL_SIZE - bounds.size * scale) / 2.0 - bounds.position * scale
	return Transform2D(0.0, Vector2(scale, scale), 0.0, offset)


func _draw_map() -> void:
	if _regions.is_empty():
		return
	var to_map := _transform()
	var font := ThemeDB.fallback_font
	for zone in get_tree().get_nodes_in_group("danger_zones"):
		var area: Rect2 = zone.danger_area
		_canvas.draw_rect(Rect2(to_map * area.position, area.size * to_map.get_scale()), DANGER)
	for region in _regions:
		var rect: Rect2 = region["rect"]
		var drawn := Rect2(to_map * rect.position, rect.size * to_map.get_scale())
		_canvas.draw_rect(drawn, Color(region["color"], 0.6))
		_canvas.draw_rect(drawn, INK, false, 2.0)
	for doorway in get_tree().get_nodes_in_group("transitions"):
		var from := to_map * Vector2(doorway.global_position.x, doorway.global_position.z)
		var to := to_map * Vector2(doorway.destination.x, doorway.destination.z)
		_canvas.draw_dashed_line(from, to, LINK, 2.0, 8.0)
		_canvas.draw_circle(from, 3.0, LINK)
	for region in _regions:
		var rect: Rect2 = region["rect"]
		var at := to_map * (rect.position + Vector2(rect.size.x / 2.0, 0)) + Vector2(0, -6)
		var width := font.get_string_size(region["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_canvas.draw_string(font, at - Vector2(width / 2.0, 0), region["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	# Quest markers, as over the NPCs' heads: ! to start, ? to hand in.
	var combatant: RefCounted = player.get_node("SimEntity").combatant if player and player.has_node("SimEntity") else null
	if combatant:
		for npc in get_tree().get_nodes_in_group("quest_npcs"):
			var marker := Quests.marker_for(combatant, npc.get_meta("npc_id"))
			if not marker.is_empty():
				var at := to_map * Vector2(npc.global_position.x, npc.global_position.z)
				_canvas.draw_string(font, at + Vector2(-4, 6), marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, QUEST_MARK)
	if player:
		var here := to_map * Vector2(player.global_position.x, player.global_position.z)
		var pulse := 5.0 + sin(Time.get_ticks_msec() / 150.0) * 1.5
		_canvas.draw_circle(here, pulse + 2.0, Color.WHITE)
		_canvas.draw_circle(here, pulse, PLAYER_MARK)
	_canvas.draw_string(font, Vector2(14, PANEL_SIZE.y - 12), "World map  (M)    You are in: %s    ! a quest to start   ? a quest to hand in" % region_at(player.global_position) if player else "World map", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
