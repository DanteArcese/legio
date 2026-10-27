extends RefCounted
## Read-only access to game content in res://content/*.json.
##
## Godot's JSON parser returns every number as a float, so integer fields are
## converted here and callers get ints. Content is validated by
## tools/content_validator.py, so this loader trusts its structure.

const CONTENT_DIR := "res://content"
const FILES := ["items", "monsters", "drops", "slayer", "player", "skilling", "shops", "pietas", "quests", "thieving", "athletics", "hunter", "farming", "mercatura", "villa", "collection", "pets", "arena"]

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		for name in FILES:
			var text := FileAccess.get_file_as_string("%s/%s.json" % [CONTENT_DIR, name])
			_data[name] = _ints(JSON.parse_string(text))
	return _data


static func pets() -> Dictionary:
	return data()["pets"]["pets"]


static func collection_pages() -> Dictionary:
	return data()["collection"]["pages"]


## Every item that appears on some collection log page.
static func is_collectable(item_id: String) -> bool:
	for page in collection_pages().values():
		if page["items"].has(item_id):
			return true
	return false


static func quest(id: String) -> Dictionary:
	return data()["quests"]["quests"].get(id, {})


## Quest ids in content order.
static func quest_ids() -> Array:
	return data()["quests"]["quests"].keys()


static func npc(id: String) -> Dictionary:
	return data()["quests"]["npcs"].get(id, {})


static func furniture(id: String) -> Dictionary:
	return data()["villa"]["furniture"].get(id, {})


static func hotspot(id: String) -> Dictionary:
	return data()["villa"]["hotspots"].get(id, {})


static func contract(id: String) -> Dictionary:
	return data()["mercatura"]["contracts"].get(id, {})


static func board(id: String) -> Dictionary:
	return data()["mercatura"]["boards"].get(id, {})


static func crop(id: String) -> Dictionary:
	return data()["farming"]["crops"].get(id, {})


static func patch(id: String) -> Dictionary:
	return data()["farming"]["patches"].get(id, {})


static func hunt_spot(id: String) -> Dictionary:
	return data()["hunter"]["spots"].get(id, {})


static func course(id: String) -> Dictionary:
	return data()["athletics"]["courses"].get(id, {})


static func stall(id: String) -> Dictionary:
	return data()["thieving"]["stalls"].get(id, {})


static func mark(id: String) -> Dictionary:
	return data()["thieving"]["marks"].get(id, {})


static func item(id: String) -> Dictionary:
	return data()["items"].get(id, {})


static func monster(id: String) -> Dictionary:
	return data()["monsters"].get(id, {})


static func drop_table(id: String) -> Dictionary:
	return data()["drops"].get(id, {})


static func venator(id: String) -> Dictionary:
	return data()["slayer"]["venatores"].get(id, {})


static func slayer_rewards() -> Dictionary:
	return data()["slayer"]["rewards"]


static func blessing(id: String) -> Dictionary:
	return data()["pietas"]["blessings"].get(id, {})


static func offering(item_id: String) -> Dictionary:
	return data()["pietas"]["offerings"].get(item_id, {})


static func shop(id: String) -> Dictionary:
	return data()["shops"].get(id, {})


static func rock(id: String) -> Dictionary:
	return data()["skilling"]["rocks"].get(id, {})


static func tree(id: String) -> Dictionary:
	return data()["skilling"]["trees"].get(id, {})


static func fishing_spot(id: String) -> Dictionary:
	return data()["skilling"]["fishing_spots"].get(id, {})


static func recipes(kind: String) -> Array:
	return data()["skilling"]["recipes"].get(kind, [])


static func recipe(kind: String, id: String) -> Dictionary:
	for entry in recipes(kind):
		if entry["id"] == id:
			return entry
	return {}


static func starting_kit() -> Array:
	return data()["player"]["starting_kit"]


static func has_item(id: String) -> bool:
	return data()["items"].has(id)


## Converts whole-number floats to ints throughout a parsed JSON value.
static func _ints(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return int(value) if value == floorf(value) else value
		TYPE_ARRAY:
			return value.map(_ints)
		TYPE_DICTIONARY:
			var result := {}
			for key in value:
				result[key] = _ints(value[key])
			return result
	return value
