extends RefCounted
## Worn items, one per slot, and the bonuses they add up to.

const ContentDB := preload("res://scripts/content/content_db.gd")

const SLOTS := ["head", "body", "weapon", "shield", "neck", "ammo"]
const UNARMED_SPEED := 4
const BONUS_KEYS := ["attack", "strength", "defence", "ranged_attack", "ranged_strength"]

## slot -> item id, or "" for empty.
var worn := {}
## How many of the worn ammo item there are (the ammo slot holds a stack).
var ammo_count := 0


func _init() -> void:
	for slot in SLOTS:
		worn[slot] = ""


static func slot_of(item_id: String) -> String:
	return ContentDB.item(item_id).get("equip", {}).get("slot", "")


## The first requirement the skills don't meet, as "attack 10", or "".
static func unmet_requirement(item_id: String, skills: RefCounted) -> String:
	var requirements: Dictionary = ContentDB.item(item_id).get("requirements", {})
	for skill in requirements:
		if skills.level(skill) < requirements[skill]:
			return "%s %d" % [skill, requirements[skill]]
	return ""


## Puts an item on and returns whatever it replaced ("" if nothing).
func wear(item_id: String) -> String:
	var slot := slot_of(item_id)
	var previous: String = worn[slot]
	worn[slot] = item_id
	return previous


func take_off(slot: String) -> String:
	var item_id: String = worn.get(slot, "")
	if not item_id.is_empty():
		worn[slot] = ""
	if slot == "ammo":
		ammo_count = 0
	return item_id


## The worn weapon's equip data, or {} when unarmed.
func weapon() -> Dictionary:
	return ContentDB.item(worn["weapon"])["equip"] if not worn["weapon"].is_empty() else {}


func is_ranged() -> bool:
	return weapon().get("style", "melee") == "ranged"


## Whether the worn ammo suits the worn ranged weapon, and there is some.
func has_ammo() -> bool:
	if worn["ammo"].is_empty() or ammo_count <= 0:
		return false
	return ContentDB.item(worn["ammo"])["equip"].get("ammo_type", "") == weapon().get("ammo", "")


func is_wearing(item_id: String) -> bool:
	return worn.values().has(item_id)


func bonuses() -> Dictionary:
	var total := {}
	for key in BONUS_KEYS:
		total[key] = 0
	for item_id in worn.values():
		if item_id.is_empty():
			continue
		var item_bonuses: Dictionary = ContentDB.item(item_id)["equip"]["bonuses"]
		for key in item_bonuses:
			total[key] += item_bonuses[key]
	return total


func attack_speed() -> int:
	var weapon: String = worn["weapon"]
	return ContentDB.item(weapon)["equip"]["attack_speed"] if not weapon.is_empty() else UNARMED_SPEED
