extends RefCounted
## Pets: very rare companions from content/pets.json. A skill pet has a
## chance on each XP drop in its skill; a monster pet has a chance on each
## kill. Using a pet lets it out to follow you (one at a time); it can be
## picked up again. Pets are never lost on death.

const Combatant := preload("res://scripts/sim/combatant.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

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


static func is_pet(item_id: String) -> bool:
	return ContentDB.item(item_id).has("pet")


## Rolls for skill pets after XP in skill.
func on_xp(player: Combatant, skill: String, events: Array) -> void:
	var pets := ContentDB.pets()
	for pet_id in pets:
		var pet: Dictionary = pets[pet_id]
		if pet["source"] == "skill" and pet["skill"] == skill:
			_roll(player, pet_id, pet["one_in"], events)


## Rolls for monster pets after a kill.
func on_kill(player: Combatant, monster_id: String, events: Array) -> void:
	var pets := ContentDB.pets()
	for pet_id in pets:
		var pet: Dictionary = pets[pet_id]
		if pet["source"] == "monster" and pet["monster"] == monster_id:
			_roll(player, pet_id, pet["one_in"], events)


func owns(player: Combatant, pet_id: String) -> bool:
	return player.pet == pet_id or player.inventory.count(pet_id) > 0 or player.bank.count(pet_id) > 0


## Lets the pet in an inventory slot out to follow the player.
func release(player: Combatant, slot_index: int, events: Array) -> void:
	var slot: Variant = player.inventory.slots[slot_index] if slot_index >= 0 and slot_index < player.inventory.slots.size() else null
	if slot == null or not is_pet(slot["item"]):
		return
	if not player.pet.is_empty():
		sim.message(player, "You already have a follower.", events)
		return
	player.inventory.take_slot(slot_index)
	player.pet = slot["item"]
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
	events.append({"type": "pet_changed", "id": player.id, "pet": player.pet, "tick": sim.tick})


## Picks the following pet back up into the inventory.
func pick_up(player: Combatant, events: Array) -> void:
	if player.pet.is_empty():
		return
	if player.inventory.space_for(player.pet, 1) < 1:
		sim.message(player, "You don't have enough inventory space.", events)
		return
	player.inventory.add(player.pet, 1)
	player.pet = ""
	events.append({"type": "inventory_changed", "id": player.id, "tick": sim.tick})
	events.append({"type": "pet_changed", "id": player.id, "pet": "", "tick": sim.tick})


func _roll(player: Combatant, pet_id: String, one_in: int, events: Array) -> void:
	if sim.rng.randi_range(1, one_in) != 1:
		return
	if owns(player, pet_id):
		sim.message(player, "You have a funny feeling you would have been followed...", events)
		return
	events.append({"type": "pet_drop", "id": player.id, "pet": pet_id, "tick": sim.tick})
	if player.pet.is_empty():
		player.pet = pet_id
		sim.record_collection(player, pet_id, 1, events)
		events.append({"type": "pet_changed", "id": player.id, "pet": pet_id, "tick": sim.tick})
		sim.message(player, "You have a funny feeling you're being followed.", events)
	else:
		sim.give_item(player.id, pet_id, 1, "pet", events)
		sim.message(player, "You feel something weird sneaking into your backpack.", events)
