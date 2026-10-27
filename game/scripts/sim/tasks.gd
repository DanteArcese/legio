extends RefCounted
## Region tasks: a short list for each region of things worth doing there
## (get an item, kill a monster, finish a quest, reach a level, visit a
## place). The simulation reports what happens; this ticks tasks off, says
## so, and pays when a region's list is done. Content in tasks.json.

const Combatant := preload("res://scripts/sim/combatant.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

## How often visit tasks check where players stand.
const VISIT_INTERVAL := 5

## Held weakly: the simulation owns this module, so a strong reference back
## would form a cycle that is never freed.
var sim: RefCounted:
	get:
		return _sim_ref.get_ref()
	set(value):
		_sim_ref = weakref(value)
var _sim_ref: WeakRef


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


static func regions() -> Dictionary:
	return ContentDB.data()["tasks"]["regions"]


static func key(region_id: String, task_id: String) -> String:
	return "%s/%s" % [region_id, task_id]


## How many of a region's tasks the player has done, and how many there are.
static func progress(player: Combatant, region_id: String) -> Array:
	var tasks: Array = regions()[region_id]["tasks"]
	var done := tasks.filter(func(task): return player.tasks_done.has(key(region_id, task["id"]))).size()
	return [done, tasks.size()]


func on_obtain(player: Combatant, item_id: String, events: Array) -> void:
	_match(player, func(task): return task["kind"] == "obtain" and task["item"] == item_id, events)


func on_kill(player: Combatant, monster_id: String, events: Array) -> void:
	_match(player, func(task): return task["kind"] == "kill" and task["monster"] == monster_id, events)


func on_quest(player: Combatant, quest_id: String, events: Array) -> void:
	_match(player, func(task): return task["kind"] == "quest" and task["quest"] == quest_id, events)


func on_level(player: Combatant, skill: String, level: int, events: Array) -> void:
	_match(player, func(task): return task["kind"] == "level" and task["skill"] == skill and level >= task["level"], events)


## Visit tasks: done on standing inside the task's area.
func process(players: Array, events: Array) -> void:
	if sim.tick % VISIT_INTERVAL != 0:
		return
	for player: Combatant in players:
		var here := Vector2(player.position.x, player.position.z)
		_match(player, func(task): return task["kind"] == "visit" \
			and Rect2(task["area"][0], task["area"][1], task["area"][2], task["area"][3]).has_point(here), events)


func _match(player: Combatant, wanted: Callable, events: Array) -> void:
	if not player.is_player():
		return
	for region_id in regions():
		var region: Dictionary = regions()[region_id]
		for task in region["tasks"]:
			var id := key(region_id, task["id"])
			if player.tasks_done.has(id) or not wanted.call(task):
				continue
			player.tasks_done.append(id)
			sim.message(player, "Task done (%s): %s" % [region["name"], task["text"]], events)
			events.append({"type": "task_done", "id": player.id, "region": region_id, "task": task["id"], "tick": sim.tick})
			var count := progress(player, region_id)
			if count[0] == count[1]:
				sim.give_item(player.id, "coins", region["reward"], "task", events)
				sim.message(player, "Every %s task done! You're paid %d denarii." % [region["name"], region["reward"]], events)
				events.append({"type": "region_tasks_done", "id": player.id, "region": region_id, "tick": sim.tick})
