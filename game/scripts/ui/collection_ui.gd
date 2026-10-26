extends CanvasLayer
## The collection log, or Tabularium (L / right trigger): a page per source,
## listing the notable items obtained there and how many, with missing ones
## greyed out. D-pad or arrow keys move between pages.

const ContentDB := preload("res://scripts/content/content_db.gd")

const MISSING := Color(0.5, 0.48, 0.45)
const FOUND := Color(0.95, 0.85, 0.5)

@export var driver: Node
@export var player: Node

var _panel: PanelContainer
var _pages := {}
var _total: Label
var _title: Label
var _items: VBoxContainer
var _page := ""


func _ready() -> void:
	_build()
	driver.sim_event.connect(func(event: Dictionary): if is_open() and event["type"] == "collection_new": _refresh())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("collection_log"):
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
		_refresh()
		_pages[_page].grab_focus()
	else:
		var focused := get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()


## Item lines on the shown page, for tests: "Wolf pelt  x3" or "Wolf pelt  -".
func item_lines() -> Array:
	return _items.get_children().map(func(label: Label): return label.text)


func total_text() -> String:
	return _total.text


func show_page(page_id: String) -> void:
	_page = page_id
	_refresh()


func _collection() -> Dictionary:
	var combatant: RefCounted = player.get_node("SimEntity").combatant
	return combatant.collection if combatant else {}


## Unique items obtained out of all those listed, counting each item once
## even if it appears on several pages.
static func totals(collection: Dictionary) -> Vector2i:
	var listed := {}
	for page in ContentDB.collection_pages().values():
		for item_id in page["items"]:
			listed[item_id] = true
	var found := listed.keys().filter(func(item_id): return collection.has(item_id)).size()
	return Vector2i(found, listed.size())


func _refresh() -> void:
	var collection := _collection()
	var pages := ContentDB.collection_pages()
	for page_id in pages:
		var page: Dictionary = pages[page_id]
		var found: int = page["items"].filter(func(item_id): return collection.has(item_id)).size()
		_pages[page_id].text = "%s  %d/%d" % [page["name"], found, page["items"].size()]
		_pages[page_id].modulate = FOUND if found == page["items"].size() else Color.WHITE
	var total := totals(collection)
	_total.text = "Collected %d of %d" % [total.x, total.y]
	var shown: Dictionary = pages[_page]
	_title.text = "%s  (%s)" % [shown["name"], shown["category"]]
	for child in _items.get_children():
		child.queue_free()
		_items.remove_child(child)
	for item_id in shown["items"]:
		var label := Label.new()
		var count: int = collection.get(item_id, 0)
		label.text = "%s  %s" % [ContentDB.item(item_id)["name"], "x%d" % count if count > 0 else "-"]
		label.add_theme_color_override("font_color", FOUND if count > 0 else MISSING)
		_items.add_child(label)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.position -= Vector2(300, 220)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.08, 0.93)
	style.set_content_margin_all(14)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	var heading := Label.new()
	heading.text = "Tabularium  (L / right trigger)"
	heading.add_theme_font_size_override("font_size", 20)
	column.add_child(heading)
	_total = Label.new()
	column.add_child(_total)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var list := VBoxContainer.new()
	row.add_child(list)
	for page_id in ContentDB.collection_pages():
		var button := Button.new()
		button.custom_minimum_size = Vector2(260, 32)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_entered.connect(show_page.bind(page_id))
		button.pressed.connect(show_page.bind(page_id))
		list.add_child(button)
		_pages[page_id] = button
		if _page.is_empty():
			_page = page_id
	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(300, 0)
	row.add_child(detail)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	detail.add_child(_title)
	_items = VBoxContainer.new()
	detail.add_child(_items)
	_panel.visible = false
