extends RefCounted
## Read-only access to game content in res://content/*.json.
##
## Godot's JSON parser returns every number as a float, so integer fields are
## converted here and callers get ints. Content is validated by
## tools/content_validator.py, so this loader trusts its structure.

const CONTENT_DIR := "res://content"
const FILES := ["items", "monsters", "drops", "slayer", "player", "skilling"]

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		for name in FILES:
			var text := FileAccess.get_file_as_string("%s/%s.json" % [CONTENT_DIR, name])
			_data[name] = _ints(JSON.parse_string(text))
	return _data


static func item(id: String) -> Dictionary:
	return data()["items"].get(id, {})


static func monster(id: String) -> Dictionary:
	return data()["monsters"].get(id, {})


static func drop_table(id: String) -> Dictionary:
	return data()["drops"].get(id, {})


static func venator(id: String) -> Dictionary:
	return data()["slayer"]["venatores"].get(id, {})


static func rock(id: String) -> Dictionary:
	return data()["skilling"]["rocks"].get(id, {})


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
