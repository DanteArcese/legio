extends CanvasLayer
## Inventory, equipment, and bank panels, plus a message line.
##
## Everything works with a controller: the D-pad moves focus, A uses the
## focused slot, Y opens its options menu, and B closes the bank. With mouse:
## left-click uses, right-click opens options.

const ContentDB := preload("res://scripts/content/content_db.gd")
const Equipment := preload("res://scripts/sim/equipment.gd")
const Skilling := preload("res://scripts/sim/skilling.gd")

const SLOT_SIZE := Vector2(92, 60)
const MESSAGE_DURATION := 4.0

@export var driver: Node
@export var player: Node

var _inventory_panel: PanelContainer
var _inventory_buttons: Array[Button] = []
var _equipment_buttons := {}
var _bonus_label: Label
var _bank_panel: PanelContainer
var _bank_grid: GridContainer
var _menu: PopupMenu
var _message: Label
var _menu_actions: Array[Callable] = []
var _blessings_panel: PanelContainer
var _favour_label: Label
var _blessing_buttons := {}


func _ready() -> void:
	_build_inventory()
	_build_bank()
	_build_blessings()
	_menu = PopupMenu.new()
	_menu.id_pressed.connect(func(index): _menu_actions[index].call())
	add_child(_menu)
	_message = Label.new()
	# Full width, centred text, so long messages stay on screen.
	_message.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Just above the HUD's status panel.
	_message.position.y -= 215
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 24)
	_message.add_theme_constant_override("outline_size", 6)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_message)

	driver.sim_event.connect(_on_sim_event)
	player.bank_opened.connect(open_bank)
	player.station_opened.connect(open_station)
	player.world_menu_requested.connect(_show_menu)
	player.message_requested.connect(show_message)
	_refresh.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pietas_menu"):
		toggle_blessings()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _bank_panel.visible:
		close_bank()
		get_viewport().set_input_as_handled()


## Blessings panel (P / D-pad left): one button per blessing, A toggles.
func toggle_blessings() -> void:
	_blessings_panel.visible = not _blessings_panel.visible
	if _blessings_panel.visible:
		_refresh_blessings()
		_blessing_buttons.values()[0].grab_focus()
	else:
		_release_focus()


func is_blessings_open() -> bool:
	return _blessings_panel.visible


func _build_blessings() -> void:
	_blessings_panel = _panel(Control.PRESET_CENTER_LEFT, Vector2(30, -260))
	var column := VBoxContainer.new()
	_blessings_panel.add_child(column)
	column.add_child(_heading("Blessings  (P / D-pad left)"))
	_favour_label = Label.new()
	column.add_child(_favour_label)
	var blessings: Dictionary = ContentDB.data()["pietas"]["blessings"]
	var ids := blessings.keys()
	ids.sort_custom(func(a, b): return blessings[a]["level"] < blessings[b]["level"])
	for id in ids:
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(330, 34)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_act.bind("bless", {"blessing": id}))
		column.add_child(button)
		_blessing_buttons[id] = button
	_blessings_panel.visible = false


func _refresh_blessings() -> void:
	var c := _combatant()
	if c == null or _blessings_panel == null:
		return
	_favour_label.text = "Favour %d / %d" % [ceili(c.favour), c.skills.level("pietas")]
	for id in _blessing_buttons:
		var blessing := ContentDB.blessing(id)
		var button: Button = _blessing_buttons[id]
		var family := "" if blessing["family"] == "heavenly" else "  (underworld)"
		button.text = "%s  - Pietas %d%s" % [blessing["name"], blessing["level"], family]
		button.set_pressed_no_signal(c.blessings.has(id))
		button.disabled = c.skills.level("pietas") < blessing["level"]


func toggle_inventory() -> void:
	_inventory_panel.visible = not _inventory_panel.visible
	if _inventory_panel.visible:
		_refresh()
		_inventory_buttons[0].grab_focus()
	elif not _bank_panel.visible:
		_release_focus()


func open_bank() -> void:
	_bank_panel.visible = true
	_inventory_panel.visible = true
	_refresh()
	var first: Control = _bank_grid.get_child(0) if _bank_grid.get_child_count() > 0 else _inventory_buttons[0]
	first.grab_focus()


## Shows what can be made at a station; picking one makes as many as possible.
func open_station(station: Node) -> void:
	_show_recipes(station.recipe_kind(), ContentDB.recipes(station.recipe_kind()))


## Fletching and sewing need no station: shows the recipes that use this item.
func open_handheld(kind: String, item_id: String) -> void:
	_show_recipes(kind, _recipes_using(kind, item_id))


## The first handheld recipe kind that uses this item, or "".
func _handheld_kind_for(item_id: String) -> String:
	for kind in Skilling.HANDHELD_KINDS:
		if not _recipes_using(kind, item_id).is_empty():
			return kind
	return ""


func _show_recipes(kind: String, recipes: Array) -> void:
	var skill: String = Skilling.SKILL_FOR_KIND[kind]
	var options := []
	var combatant := _combatant()
	for recipe in recipes:
		# Recipes taught by a quest stay hidden until it's done.
		if recipe.has("requires_quest") and not combatant.quests.get(recipe["requires_quest"], {}).get("done", false):
			continue
		var label := "%s  (%s %d)" % [ContentDB.item(recipe["output"])["name"], skill.capitalize(), recipe["level"]]
		options.append([label, _act.bind("craft", {"kind": kind, "recipe": recipe["id"], "count": 28})])
	_show_menu(options, get_viewport().get_visible_rect().size / 2.0)


func _recipes_using(kind: String, item_id: String) -> Array:
	return ContentDB.recipes(kind).filter(func(recipe):
		return recipe["inputs"].any(func(entry): return entry["item"] == item_id))


func close_bank() -> void:
	_bank_panel.visible = false
	_inventory_panel.visible = false
	_release_focus()


func is_bank_open() -> bool:
	return _bank_panel.visible


func show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	var tween := _message.create_tween()
	tween.tween_property(_message, "modulate:a", 0.0, 0.6).set_delay(MESSAGE_DURATION)


func _combatant() -> RefCounted:
	return player.get_node("SimEntity").combatant


func _player_id() -> int:
	return player.get_node("SimEntity").entity_id


func _act(action: String, args := {}) -> void:
	driver.sim.queue_item_action(_player_id(), action, args)


func _on_sim_event(event: Dictionary) -> void:
	if event.get("id") != _player_id():
		return
	match event["type"]:
		"blessings_changed", "favour_changed":
			_refresh_blessings.call_deferred()
		"inventory_changed", "equipment_changed", "bank_changed":
			_refresh.call_deferred()
		"message":
			show_message(event["text"])
		"ate":
			show_message("You eat the %s." % ContentDB.item(event["item"])["name"].to_lower())


# --- Building -----------------------------------------------------------

func _build_inventory() -> void:
	_inventory_panel = _panel(Control.PRESET_CENTER_RIGHT, Vector2(-410, -330))
	var column := VBoxContainer.new()
	_inventory_panel.add_child(column)
	column.add_child(_heading("Inventory  (I / Back)"))
	var grid := GridContainer.new()
	grid.columns = 4
	column.add_child(grid)
	for i in 28:
		var button := _slot_button()
		button.pressed.connect(_use_inventory_slot.bind(i))
		button.gui_input.connect(_on_slot_input.bind(button, _inventory_options.bind(i)))
		grid.add_child(button)
		_inventory_buttons.append(button)
	column.add_child(_heading("Equipment"))
	var equip_grid := GridContainer.new()
	equip_grid.columns = 3
	column.add_child(equip_grid)
	for slot in Equipment.SLOTS:
		var button := _slot_button()
		button.custom_minimum_size = Vector2(124, 44)
		button.pressed.connect(_act.bind("unequip", {"equip_slot": slot}))
		equip_grid.add_child(button)
		_equipment_buttons[slot] = button
	_bonus_label = Label.new()
	column.add_child(_bonus_label)
	_inventory_panel.visible = false


func _build_bank() -> void:
	_bank_panel = _panel(Control.PRESET_CENTER_LEFT, Vector2(30, -300))
	var column := VBoxContainer.new()
	_bank_panel.add_child(column)
	column.add_child(_heading("Bank  (B / Esc to close)"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(4 * (SLOT_SIZE.x + 4) + 16, 420)
	column.add_child(scroll)
	_bank_grid = GridContainer.new()
	_bank_grid.columns = 4
	scroll.add_child(_bank_grid)
	var deposit_all := Button.new()
	deposit_all.text = "Deposit inventory"
	deposit_all.pressed.connect(_act.bind("deposit_all"))
	column.add_child(deposit_all)
	_bank_panel.visible = false


func _panel(preset: Control.LayoutPreset, offset: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(preset)
	panel.position += offset
	add_child(panel)
	return panel


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	return label


func _slot_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = SLOT_SIZE
	button.clip_text = true
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 14)
	return button


# --- Refreshing ---------------------------------------------------------

func _refresh() -> void:
	var c := _combatant()
	if c == null:
		return
	for i in 28:
		var slot: Variant = c.inventory.slots[i]
		_inventory_buttons[i].text = _slot_text(slot)
		_inventory_buttons[i].tooltip_text = ContentDB.item(slot["item"])["examine"] if slot else ""
	for slot in Equipment.SLOTS:
		var item_id: String = c.equipment.worn[slot]
		var label: String = ContentDB.item(item_id)["name"] if not item_id.is_empty() else "-"
		if slot == "ammo" and not item_id.is_empty():
			label += " x%d" % c.equipment.ammo_count
		_equipment_buttons[slot].text = "%s: %s" % [slot.capitalize(), label]
	_bonus_label.text = "Melee +%d/+%d   Ranged +%d/+%d   Ritus +%d/+%d\nDefence +%d (vs Ranged %+d, vs Ritus %+d)   Speed %d" % [
		c.bonuses["attack"], c.bonuses["strength"], c.bonuses["ranged_attack"], c.bonuses["ranged_strength"],
		c.bonuses["ritus_attack"], c.bonuses["ritus_strength"], c.bonuses["defence"],
		c.defence_bonus_against("ranged"), c.defence_bonus_against("ritus"), c.current_attack_speed()]
	if _bank_panel.visible:
		_refresh_bank(c)


func _refresh_bank(c: RefCounted) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var focus_index := focused.get_index() if focused and focused.get_parent() == _bank_grid else -1
	for child in _bank_grid.get_children():
		_bank_grid.remove_child(child)
		child.queue_free()
	for slot in c.bank.slots:
		if slot == null:
			continue
		var button := _slot_button()
		button.text = _slot_text(slot)
		button.pressed.connect(_act.bind("withdraw", {"item": slot["item"], "quantity": 1}))
		button.gui_input.connect(_on_slot_input.bind(button, _bank_options.bind(slot["item"])))
		_bank_grid.add_child(button)
	if focus_index >= 0 and _bank_grid.get_child_count() > 0:
		(_bank_grid.get_child(mini(focus_index, _bank_grid.get_child_count() - 1)) as Control).grab_focus()


func _slot_text(slot: Variant) -> String:
	if slot == null:
		return ""
	var name: String = ContentDB.item(slot["item"])["name"]
	return name if slot["quantity"] == 1 else "%s\nx%d" % [name, slot["quantity"]]


# --- Actions ------------------------------------------------------------

## A / left-click on an inventory slot: deposit at the bank, else equip or eat.
func _use_inventory_slot(index: int) -> void:
	var slot: Variant = _combatant().inventory.slots[index]
	if slot == null:
		return
	if _bank_panel.visible:
		_act("deposit", {"slot": index})
		return
	var item: Dictionary = ContentDB.item(slot["item"])
	if item.has("equip"):
		_act("equip", {"slot": index})
	elif item.has("heals"):
		_act("eat", {"slot": index})
	elif item.has("remedy"):
		_act("drink", {"slot": index})
	elif not _handheld_kind_for(slot["item"]).is_empty():
		open_handheld(_handheld_kind_for(slot["item"]), slot["item"])
	else:
		show_message(item["examine"])


func _inventory_options(index: int) -> Array:
	var slot: Variant = _combatant().inventory.slots[index]
	if slot == null:
		return []
	var item: Dictionary = ContentDB.item(slot["item"])
	var options := []
	if _bank_panel.visible:
		options.append(["Deposit 1", _act.bind("deposit", {"slot": index, "quantity": 1})])
		options.append(["Deposit all", _act.bind("deposit", {"slot": index})])
	if item.has("equip"):
		options.append(["Wear", _act.bind("equip", {"slot": index})])
	if item.has("heals"):
		options.append(["Eat", _act.bind("eat", {"slot": index})])
	if item.has("remedy"):
		options.append(["Drink", _act.bind("drink", {"slot": index})])
	for kind in Skilling.HANDHELD_KINDS:
		if not _recipes_using(kind, slot["item"]).is_empty():
			options.append([Skilling.HANDHELD_KINDS[kind], open_handheld.bind(kind, slot["item"])])
	options.append(["Drop", _act.bind("drop", {"slot": index})])
	options.append(["Examine", show_message.bind(item["examine"])])
	return options


func _bank_options(item_id: String) -> Array:
	var options := []
	for amount in [1, 5, 10]:
		options.append(["Withdraw %d" % amount, _act.bind("withdraw", {"item": item_id, "quantity": amount})])
	options.append(["Withdraw all", _act.bind("withdraw", {"item": item_id, "quantity": 1 << 30})])
	options.append(["Examine", show_message.bind(ContentDB.item(item_id)["examine"])])
	return options


## Y / right-click on a slot opens its options menu next to it.
func _on_slot_input(event: InputEvent, button: Button, options_for: Callable) -> void:
	var wants_menu: bool = event.is_action_pressed("context_menu") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)
	if not wants_menu:
		return
	button.accept_event()
	_show_menu(options_for.call(), button.get_screen_position() + Vector2(button.size.x, 0))


func _show_menu(options: Array, at: Vector2) -> void:
	if options.is_empty():
		return
	_menu.clear()
	_menu_actions.clear()
	for i in options.size():
		_menu.add_item(options[i][0], i)
		_menu_actions.append(options[i][1])
	_menu.position = Vector2i(at)
	_menu.popup()
	# Highlight the first entry so a controller can press A straight away.
	_menu.set_focused_item(0)


func is_menu_open() -> bool:
	return _menu.visible


func _release_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
