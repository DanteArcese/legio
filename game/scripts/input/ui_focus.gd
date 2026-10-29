extends RefCounted
## On a controller the D-pad and face buttons also drive menus. While a menu
## has focus, a press that the menu didn't use (the D-pad at a menu's edge,
## B or X on a slot) must not fall through to the world as a zoom, a quest
## log, a special attack or a change of style. These helpers say when to
## ignore it.

const DPAD := [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]


## True when a visible control has keyboard/controller focus.
static func menu_has_focus(viewport: Viewport) -> bool:
	var focused := viewport.gui_get_focus_owner()
	return focused != null and focused.is_visible_in_tree()


## True for a controller button press while a menu has focus.
static func pad_in_menu(event: InputEvent, viewport: Viewport) -> bool:
	return event is InputEventJoypadButton and menu_has_focus(viewport)


## True for a D-pad press while a menu has focus.
static func dpad_in_menu(event: InputEvent, viewport: Viewport) -> bool:
	return event is InputEventJoypadButton and event.button_index in DPAD and menu_has_focus(viewport)
