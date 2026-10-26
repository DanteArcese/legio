extends RefCounted
## Farming: planting seeds in patches, growth through stages over ticks,
## and harvesting. Patches belong to whoever plants them. Saves keep each
## player's patches, and time away from the game counts as growth.

const Combatant := preload("res://scripts/sim/combatant.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PATCH_RANGE := 2.4
## Seconds per tick, for turning time away into growth.
const TICK_SECONDS := 0.6

## Held weakly: the simulation owns this module, so a strong reference back
## would form a cycle that is never freed.
var sim: RefCounted:
	get:
		return _sim_ref.get_ref()
	set(value):
		_sim_ref = weakref(value)
var _sim_ref: WeakRef
## patch id -> {"id", "type", "key", "position", "crop", "owner", "stage", "next_stage"}
## crop is "" for an empty patch; stage counts up to the crop's stages (ready).
var patches := {}


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


## key is a stable name for the patch (its node name), used by saves.
func add_patch(id: int, patch_type: String, key: String, position: Vector3) -> void:
	patches[id] = {"id": id, "type": patch_type, "key": key, "position": position, "crop": "", "owner": -1, "stage": 0, "next_stage": -1}


static func crop_for_seed(seed: String) -> String:
	for crop_id in ContentDB.data()["farming"]["crops"]:
		if ContentDB.crop(crop_id)["seed"] == seed:
			return crop_id
	return ""


static func is_ready(patch: Dictionary) -> bool:
	return not patch["crop"].is_empty() and patch["stage"] >= ContentDB.crop(patch["crop"])["stages"]


## Seeds the player carries that this patch can grow.
func plantable_seeds(player: Combatant, patch_id: int) -> Array:
	var kind: String = ContentDB.patch(patches[patch_id]["type"])["kind"]
	var seeds := []
	for crop_id in ContentDB.data()["farming"]["crops"]:
		var crop := ContentDB.crop(crop_id)
		if crop["kind"] == kind and player.inventory.count(crop["seed"]) > 0:
			seeds.append(crop["seed"])
	return seeds


## Plants a seed in an empty patch, or harvests a grown one, or says how
## the crop is coming along.
func use_patch(player: Combatant, patch_id: int, seed: String, events: Array) -> void:
	var patch: Dictionary = patches.get(patch_id, {})
	if patch.is_empty() or sim.flat_distance(patch["position"], player.position) > PATCH_RANGE:
		return
	if patch["crop"].is_empty():
		_plant(player, patch, seed, events)
	elif patch["owner"] != player.id:
		sim.message(player, "Someone else is growing something here.", events)
	elif is_ready(patch):
		_harvest(player, patch, events)
	else:
		var crop := ContentDB.crop(patch["crop"])
		sim.message(player, "The %s is growing (%d of %d)." % [crop["name"].to_lower(), patch["stage"], crop["stages"]], events)


func process(events: Array) -> void:
	for patch in patches.values():
		if patch["crop"].is_empty() or is_ready(patch) or sim.tick < patch["next_stage"]:
			continue
		_grow(patch, events)


## Time away from the game: moves every crop this player planted on by ticks.
func advance(player_id: int, ticks: int, events: Array) -> void:
	for patch in patches.values():
		if patch["owner"] != player_id or patch["crop"].is_empty():
			continue
		var crop := ContentDB.crop(patch["crop"])
		var left := ticks
		# Ticks until the next stage, counted on without moving the clock.
		var to_next: int = maxi(patch["next_stage"] - sim.tick, 0)
		while left > 0 and not is_ready(patch):
			if to_next > left:
				to_next -= left
				left = 0
			else:
				left -= to_next
				patch["stage"] += 1
				to_next = crop["stage_ticks"]
		patch["next_stage"] = sim.tick + to_next
		events.append(_changed(patch))


## This player's patches for a save: [{"key", "crop", "stage", "ticks_left"}].
func capture(player_id: int) -> Array:
	var out := []
	for patch in patches.values():
		if patch["owner"] == player_id and not patch["crop"].is_empty():
			out.append({"key": patch["key"], "crop": patch["crop"], "stage": patch["stage"],
				"ticks_left": maxi(patch["next_stage"] - sim.tick, 0)})
	return out


func restore(player_id: int, saved: Array, events: Array) -> void:
	for entry in saved:
		for patch in patches.values():
			if patch["key"] != entry["key"]:
				continue
			patch["crop"] = entry["crop"]
			patch["owner"] = player_id
			patch["stage"] = int(entry["stage"])
			patch["next_stage"] = sim.tick + int(entry["ticks_left"])
			events.append(_changed(patch))


func _plant(player: Combatant, patch: Dictionary, seed: String, events: Array) -> void:
	var crop_id := crop_for_seed(seed)
	if crop_id.is_empty() or player.inventory.count(seed) == 0:
		sim.message(player, "You need seeds to plant here.", events)
		return
	var crop := ContentDB.crop(crop_id)
	if crop["kind"] != ContentDB.patch(patch["type"])["kind"]:
		sim.message(player, "That won't grow in a %s." % ContentDB.patch(patch["type"])["name"].to_lower(), events)
		return
	if player.skills.level("farming") < crop["level"]:
		sim.message(player, "You need Farming %d to grow %s." % [crop["level"], crop["name"].to_lower()], events)
		return
	if player.inventory.count("trowel") == 0:
		sim.message(player, "You need a trowel to plant seeds.", events)
		return
	player.inventory.remove(seed, 1)
	patch["crop"] = crop_id
	patch["owner"] = player.id
	patch["stage"] = 0
	patch["next_stage"] = sim.tick + crop["stage_ticks"]
	sim.award_xp(player, "farming", crop["plant_xp"], events)
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
	events.append(_changed(patch))
	sim.message(player, "You plant %s." % crop["name"].to_lower(), events)


func _grow(patch: Dictionary, events: Array) -> void:
	var crop := ContentDB.crop(patch["crop"])
	patch["stage"] += 1
	patch["next_stage"] = sim.tick + crop["stage_ticks"]
	events.append(_changed(patch))


func _harvest(player: Combatant, patch: Dictionary, events: Array) -> void:
	var crop := ContentDB.crop(patch["crop"])
	var amount: int = sim.rng.randi_range(crop["yield"][0], crop["yield"][1])
	if player.inventory.free_slots() < 1:
		sim.message(player, "You don't have enough inventory space.", events)
		return
	sim.give_item(player.id, crop["produce"], amount, "skilling", events)
	sim.award_xp(player, "farming", crop["harvest_xp"] * amount, events)
	sim.message(player, "You harvest %d %s." % [amount, crop["name"].to_lower()], events)
	patch["crop"] = ""
	patch["owner"] = -1
	patch["stage"] = 0
	patch["next_stage"] = -1
	events.append(_changed(patch))


func _changed(patch: Dictionary) -> Dictionary:
	return {"type": "patch_changed", "patch": patch["id"], "crop": patch["crop"], "stage": patch["stage"],
		"ready": is_ready(patch), "tick": sim.tick}
