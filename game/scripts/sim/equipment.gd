extends RefCounted
## Worn items, one per slot, and the bonuses they add up to.

const ContentDB := preload("res://scripts/content/content_db.gd")

const SLOTS := ["head", "body", "weapon", "shield", "neck", "ammo"]
const UNARMED_SPEED := 4
const BONUS_KEYS := ["attack", "strength", "defence", "ranged_attack", "ranged_strength",
	"ritus_attack", "ritus_strength", "ranged_defence", "ritus_defence"]

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


## "melee", "ranged", or "ritus", from the worn weapon.
func combat_kind() -> String:
	return weapon().get("style", "melee")


func is_ranged() -> bool:
	return combat_kind() == "ranged"


## Ranged weapons fire ammo and Ritus foci use up tablets from the ammo slot.
func uses_ammo() -> bool:
	return combat_kind() != "melee"


## The curse of the worn tablets ("" if none).
func curse() -> String:
	return ContentDB.item(worn["ammo"])["equip"].get("curse", "") if not worn["ammo"].is_empty() else ""


## Whether the worn ammo suits the worn weapon, and there is some.
func has_ammo() -> bool:
	if worn["ammo"].is_empty() or ammo_count <= 0:
		return false
	return ContentDB.item(worn["ammo"])["equip"].get("ammo_type", "") == weapon().get("ammo", "")


func is_wearing(item_id: String) -> bool:
	return worn.values().has(item_id)


## Whether something worn is, or counts as, this ward item (the venator's
## helm has a whitethorn charm sewn in).
func is_warded_by(item_id: String) -> bool:
	if is_wearing(item_id):
		return true
	for worn_id in worn.values():
		if not worn_id.is_empty() and item_id in ContentDB.item(worn_id)["equip"].get("wards", []):
			return true
	return false


## The largest on-task Slayer boost among worn items (0.0 if none).
func slayer_boost() -> float:
	var best := 0.0
	for worn_id in worn.values():
		if not worn_id.is_empty():
			best = maxf(best, ContentDB.item(worn_id)["equip"].get("slayer_boost", 0.0))
	return best


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
