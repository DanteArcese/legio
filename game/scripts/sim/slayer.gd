extends RefCounted
## Slayer contracts: which tasks a venator can give, gear checks, and
## Slayer level requirements. Pure functions over content and player state.

const ContentDB := preload("res://scripts/content/content_db.gd")


## Tasks this venator can give a player at these levels, minus blocked
## monsters. None below the venator's own combat level.
static func eligible_tasks(venator: Dictionary, combat_level: int, slayer_level: int, blocked := []) -> Array:
	if combat_level < venator["combat_level"]:
		return []
	return venator["tasks"].filter(func(task):
		return combat_level >= task.get("combat_level", 1) \
			and slayer_level >= task.get("slayer_level", 1) \
			and slayer_level >= required_level(task["monster"]) \
			and not blocked.has(task["monster"]))


## Picks a weighted task and amount. Returns {} if none are eligible.
static func assign(venator_id: String, combat_level: int, slayer_level: int, rng: RandomNumberGenerator, blocked := []) -> Dictionary:
	var tasks := eligible_tasks(ContentDB.venator(venator_id), combat_level, slayer_level, blocked)
	if tasks.is_empty():
		return {}
	var total := 0
	for task in tasks:
		total += task["weight"]
	var pick := rng.randi_range(1, total)
	for task in tasks:
		pick -= task["weight"]
		if pick <= 0:
			var amount := rng.randi_range(task["amount"][0], task["amount"][1])
			return {"monster": task["monster"], "remaining": amount, "total": amount, "venator": venator_id}
	return {}


## Slayer level needed to damage a monster (1 if none).
static func required_level(monster_id: String) -> int:
	return ContentDB.monster(monster_id).get("slayer", {}).get("level", 1)


## The effect that applies when fighting this monster without its ward
## item, or "" if it has none or the player wears the ward. Some wards only
## need carrying (ward_carried), like the Lemuria's black beans.
static func unwarded_effect(monster_id: String, equipment: RefCounted, inventory: RefCounted = null) -> String:
	var slayer: Dictionary = ContentDB.monster(monster_id).get("slayer", {})
	if not slayer.has("ward_item") or equipment.is_warded_by(slayer["ward_item"]):
		return ""
	if slayer.get("ward_carried", false) and inventory and inventory.count(slayer["ward_item"]) > 0:
		return ""
	return slayer["unwarded_effect"]


## Points for finishing a contract: the venator's rate, multiplied on streak
## milestones (every 10th contract pays 5x, every 50th 15x).
static func points_for(venator_id: String, tasks_done: int) -> int:
	var points: int = ContentDB.venator(venator_id)["points_per_task"]
	for streak in ContentDB.slayer_rewards()["streaks"]:
		if tasks_done % int(streak["every"]) == 0:
			return points * int(streak["multiplier"])
	return points


## The accuracy and max-hit multiplier for this attacker against this
## target: above 1.0 only for a player wearing a Slayer boost item and
## fighting their current task monster.
static func boost(attacker: RefCounted, target: RefCounted) -> float:
	if not attacker.is_player() or attacker.slayer_task.is_empty() or attacker.slayer_task["monster"] != target.monster_id:
		return 1.0
	return 1.0 + attacker.equipment.slayer_boost()


static func plural_name(monster_id: String) -> String:
	var monster := ContentDB.monster(monster_id)
	if monster.has("plural"):
		return monster["plural"].to_lower()
	var name: String = monster["name"].to_lower()
	return name if name.ends_with("s") else name + "s"
