extends RefCounted
## Deterministic, tick-based game logic.
##
## Nothing here touches scene nodes. The client queues commands and feeds in
## positions. step() advances one tick and returns events for the client to
## render. With the same seed and inputs, the same events come out, which
## keeps the logic testable and lets it move to a server later.

const Combatant := preload("res://scripts/sim/combatant.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const CombatMath := preload("res://scripts/sim/combat_math.gd")
const Drops := preload("res://scripts/sim/drops.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")
const ItemContainer := preload("res://scripts/sim/item_container.gd")
const Equipment := preload("res://scripts/sim/equipment.gd")

const INVENTORY_SIZE := 28
const BANK_SIZE := 400
## Ground items disappear after this many ticks (2 minutes).
const GROUND_LIFETIME := 200
const PICKUP_RANGE := 2.0
const BANK_RANGE := 3.0
## Eating delays your next attack by this many ticks.
const EAT_DELAY := 3
## Where items can come from. Solitarius accounts refuse the restricted ones.
const SOLITARIUS_BLOCKED_SOURCES := ["market", "trade"]

## Every combatant regains 1 HP this often.
const REGEN_INTERVAL := 100
## Chance per idle tick that a monster wanders somewhere new.
const WANDER_CHANCE := 0.1
## Aggressive monsters ignore players above this multiple of their level.
const AGGRO_LEVEL_MULTIPLIER := 2

var tick := 0
var rng := RandomNumberGenerator.new()

var _combatants := {}
var _pending_commands: Array[Dictionary] = []
## pile id -> {"id", "position", "items", "expires_at"}
var _ground := {}
var _next_pile_id := 1
var _banks: Array[Vector3] = []


func _init(seed_value := 0) -> void:
	rng.seed = seed_value


func add_combatant(id: int) -> Combatant:
	var combatant := Combatant.new(id)
	_combatants[id] = combatant
	return combatant


## Creates a monster from content, with its brain enabled.
func add_monster(id: int, monster_id: String, spawn: Vector3) -> Combatant:
	var data := ContentDB.monster(monster_id)
	var combatant := add_combatant(id)
	combatant.monster_id = monster_id
	combatant.drop_table = data["drops"]
	combatant.display_level = data["level"]
	combatant.max_hp = data["stats"]["vitality"]
	combatant.hp = combatant.max_hp
	for skill in ["attack", "strength", "defence"]:
		combatant.levels[skill] = data["stats"][skill]
	combatant.attack_speed = data["attack_speed"]
	combatant.respawn_ticks = data["respawn_ticks"]
	combatant.has_brain = true
	combatant.aggressive = data["aggressive"]
	combatant.spawn_position = spawn
	combatant.position = spawn
	return combatant


## Creates a player with skills, an empty inventory, equipment, and a bank.
func add_player(id: int, position := Vector3.ZERO) -> Combatant:
	var player := add_combatant(id)
	player.skills = Skills.new()
	player.max_hp = player.skills.level("vitality")
	player.hp = player.max_hp
	player.inventory = ItemContainer.new(INVENTORY_SIZE)
	player.equipment = Equipment.new()
	player.bank = ItemContainer.new(BANK_SIZE, true)
	player.position = position
	player.apply_equipment()
	return player


func give_starting_kit(id: int) -> void:
	for entry in ContentDB.starting_kit():
		give_item(id, entry["item"], entry["quantity"], "starting_kit", [])


func add_bank(position: Vector3) -> void:
	_banks.append(position)


func ground_piles() -> Array:
	return _ground.values()


## The single path for items entering a player's inventory. Applies account
## mode rules, and drops whatever doesn't fit on the ground at the player's
## feet. Returns how many reached the inventory.
func give_item(id: int, item_id: String, quantity: int, source: String, events: Array) -> int:
	var player: Combatant = _combatants[id]
	if player.account_mode == "solitarius" and source in SOLITARIUS_BLOCKED_SOURCES:
		events.append({"type": "message", "id": id, "text": "As a Solitarius, you stand alone.", "tick": tick})
		return 0
	var added: int = player.inventory.add(item_id, quantity)
	if added < quantity:
		_add_ground_pile(player.position, [{"item": item_id, "quantity": quantity - added}], events)
	if added > 0:
		events.append({"type": "inventory_changed", "id": id, "tick": tick})
	return added


func get_combatant(id: int) -> Combatant:
	return _combatants.get(id)


func set_position(id: int, position: Vector3) -> void:
	_combatants[id].position = position


## Queues a command for the next tick. Commands are never applied mid-tick,
## and none are lost when several arrive between ticks.
func queue_command(command: Dictionary) -> void:
	_pending_commands.append(command)


func queue_attack(actor_id: int, target_id: int) -> void:
	queue_command({"type": "attack", "actor": actor_id, "target": target_id})


func queue_stop(actor_id: int) -> void:
	queue_command({"type": "stop", "actor": actor_id})


func queue_style(actor_id: int, style: String) -> void:
	queue_command({"type": "style", "actor": actor_id, "style": style})


## Inventory and bank commands. slot is an inventory slot index.
func queue_item_action(actor_id: int, action: String, args := {}) -> void:
	var command := {"type": action, "actor": actor_id}
	command.merge(args)
	queue_command(command)


## Advances one tick and returns the events that happened during it.
func step() -> Array[Dictionary]:
	tick += 1
	var events: Array[Dictionary] = []
	_apply_commands(events)
	_expire_ground(events)
	_process_respawns(events)
	# Sorted ids keep processing order, and therefore RNG use, deterministic.
	var ids := _combatants.keys()
	ids.sort()
	for id in ids:
		var combatant: Combatant = _combatants[id]
		if combatant.has_brain:
			_think(combatant)
	for id in ids:
		_process_attack(_combatants[id], events)
	if tick % REGEN_INTERVAL == 0:
		_regenerate()
	return events


func _apply_commands(events: Array[Dictionary]) -> void:
	var commands := _pending_commands
	_pending_commands = []
	for command in commands:
		var actor: Combatant = _combatants.get(command["actor"])
		if actor == null or not actor.is_alive():
			continue
		match command["type"]:
			"attack":
				var target: Combatant = _combatants.get(command["target"])
				if target != null and target.is_alive() and target != actor:
					actor.target_id = target.id
			"stop":
				actor.target_id = -1
			"style":
				if command["style"] in Skills.STYLES:
					actor.style = command["style"]
			_:
				if actor.inventory:
					_apply_item_command(actor, command, events)


func _apply_item_command(player: Combatant, command: Dictionary, events: Array[Dictionary]) -> void:
	var slot_index: int = command.get("slot", -1)
	var slot: Variant = player.inventory.slots[slot_index] if slot_index >= 0 and slot_index < player.inventory.size else null
	match command["type"]:
		"equip":
			if slot == null or Equipment.slot_of(slot["item"]).is_empty():
				return
			var unmet := Equipment.unmet_requirement(slot["item"], player.skills)
			if not unmet.is_empty():
				_message(player, "You need %s to wear that." % unmet.capitalize(), events)
				return
			player.inventory.take_slot(slot_index)
			var previous: String = player.equipment.wear(slot["item"])
			if not previous.is_empty():
				player.inventory.slots[slot_index] = {"item": previous, "quantity": 1}
			_equipment_changed(player, events)
		"unequip":
			var item_id: String = player.equipment.worn.get(command.get("equip_slot", ""), "")
			if item_id.is_empty():
				return
			if player.inventory.space_for(item_id, 1) == 0:
				_message(player, "You don't have enough inventory space.", events)
				return
			player.equipment.take_off(command["equip_slot"])
			player.inventory.add(item_id, 1)
			_equipment_changed(player, events)
		"eat":
			if slot == null or not ContentDB.item(slot["item"]).has("heals"):
				return
			_remove_from_slot(player, slot_index, 1)
			var heal: int = ContentDB.item(slot["item"])["heals"]
			var healed := mini(heal, player.max_hp - player.hp)
			player.hp += healed
			player.next_attack_tick = maxi(player.next_attack_tick, tick + EAT_DELAY)
			events.append({"type": "ate", "id": player.id, "item": slot["item"], "healed": healed, "tick": tick})
			events.append({"type": "inventory_changed", "id": player.id, "tick": tick})
		"drop":
			if slot == null:
				return
			player.inventory.take_slot(slot_index)
			_add_ground_pile(player.position, [slot], events)
			events.append({"type": "inventory_changed", "id": player.id, "tick": tick})
		"pickup":
			_pickup(player, command.get("pile", -1), events)
		"deposit", "deposit_all", "withdraw":
			if not _near_bank(player):
				_message(player, "You need to be at a bank.", events)
				return
			_bank_command(player, command, slot, events)


func _remove_from_slot(player: Combatant, index: int, quantity: int) -> void:
	var slot: Dictionary = player.inventory.slots[index]
	slot["quantity"] -= quantity
	if slot["quantity"] <= 0:
		player.inventory.slots[index] = null


func _bank_command(player: Combatant, command: Dictionary, slot: Variant, events: Array[Dictionary]) -> void:
	match command["type"]:
		"deposit":
			if slot == null:
				return
			var item_id: String = slot["item"]
			var quantity := mini(command.get("quantity", player.inventory.count(item_id)), player.inventory.count(item_id))
			var moved: int = player.bank.add(item_id, quantity)
			player.inventory.remove(item_id, moved)
		"deposit_all":
			for item_id in _distinct_items(player.inventory):
				player.inventory.remove(item_id, player.bank.add(item_id, player.inventory.count(item_id)))
		"withdraw":
			var item_id: String = command.get("item", "")
			var quantity := mini(command.get("quantity", 1), player.bank.count(item_id))
			var moved: int = player.inventory.add(item_id, quantity)
			player.bank.remove(item_id, moved)
			if moved < quantity:
				_message(player, "You don't have enough inventory space.", events)
	events.append({"type": "inventory_changed", "id": player.id, "tick": tick})
	events.append({"type": "bank_changed", "id": player.id, "tick": tick})


func _distinct_items(container: RefCounted) -> Array:
	var ids := []
	for slot in container.slots:
		if slot and not ids.has(slot["item"]):
			ids.append(slot["item"])
	return ids


func _equipment_changed(player: Combatant, events: Array[Dictionary]) -> void:
	player.apply_equipment()
	events.append({"type": "equipment_changed", "id": player.id, "tick": tick})
	events.append({"type": "inventory_changed", "id": player.id, "tick": tick})


func _message(player: Combatant, text: String, events: Array[Dictionary]) -> void:
	events.append({"type": "message", "id": player.id, "text": text, "tick": tick})


func _near_bank(player: Combatant) -> bool:
	return _banks.any(func(bank): return _flat_distance(bank, player.position) <= BANK_RANGE)


func _pickup(player: Combatant, pile_id: int, events: Array[Dictionary]) -> void:
	var pile: Dictionary = _ground.get(pile_id, {})
	if pile.is_empty() or _flat_distance(pile["position"], player.position) > PICKUP_RANGE:
		return
	var remaining := []
	var took_any := false
	for entry in pile["items"]:
		var added: int = player.inventory.add(entry["item"], entry["quantity"])
		took_any = took_any or added > 0
		if added < entry["quantity"]:
			remaining.append({"item": entry["item"], "quantity": entry["quantity"] - added})
	if took_any:
		events.append({"type": "inventory_changed", "id": player.id, "tick": tick})
	if remaining.is_empty():
		_ground.erase(pile_id)
		events.append({"type": "ground_remove", "pile": pile_id, "tick": tick})
	else:
		pile["items"] = remaining
		events.append({"type": "ground_update", "pile": pile_id, "items": remaining, "tick": tick})
		_message(player, "You don't have enough inventory space.", events)


func _add_ground_pile(position: Vector3, items: Array, events: Array) -> void:
	var pile := {"id": _next_pile_id, "position": position, "items": items.duplicate(true), "expires_at": tick + GROUND_LIFETIME}
	_ground[_next_pile_id] = pile
	_next_pile_id += 1
	events.append({"type": "ground_add", "pile": pile["id"], "position": position, "items": pile["items"], "tick": tick})


func _expire_ground(events: Array[Dictionary]) -> void:
	for pile_id in _ground.keys():
		if _ground[pile_id]["expires_at"] <= tick:
			_ground.erase(pile_id)
			events.append({"type": "ground_remove", "pile": pile_id, "tick": tick})


func _process_respawns(events: Array[Dictionary]) -> void:
	for combatant in _combatants.values():
		if combatant.respawn_at_tick == tick:
			combatant.hp = combatant.max_hp
			combatant.respawn_at_tick = -1
			combatant.returning = false
			combatant.move_target = null
			if combatant.has_brain:
				combatant.position = combatant.spawn_position
			events.append({"type": "respawn", "id": combatant.id, "tick": tick})


## Monster AI: leash, chase, aggro, or wander. Decides where to move; the
## scene does the moving and reports positions back.
func _think(monster: Combatant) -> void:
	if not monster.is_alive():
		return
	var from_spawn := _flat_distance(monster.position, monster.spawn_position)
	if monster.returning:
		if from_spawn <= 1.0:
			monster.returning = false
			monster.move_target = null
		return
	if monster.target_id != -1 and from_spawn > monster.leash_radius:
		monster.target_id = -1
		monster.returning = true
		monster.move_target = monster.spawn_position
		return

	var target: Combatant = _combatants.get(monster.target_id)
	if target == null and monster.aggressive:
		target = _find_aggro_target(monster)
		if target:
			monster.target_id = target.id
	if target and target.is_alive():
		var in_reach := _flat_distance(monster.position, target.position) <= monster.reach * 0.9
		monster.move_target = null if in_reach else target.position
	elif rng.randf() < WANDER_CHANCE:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(0.0, monster.wander_radius)
		monster.move_target = monster.spawn_position + Vector3(cos(angle), 0.0, sin(angle)) * distance


func _find_aggro_target(monster: Combatant) -> Combatant:
	var best: Combatant = null
	var best_distance := monster.aggro_radius
	for combatant in _combatants.values():
		if not combatant.is_player() or not combatant.is_alive():
			continue
		if combatant.combat_level() > monster.display_level * AGGRO_LEVEL_MULTIPLIER:
			continue
		var distance := _flat_distance(monster.position, combatant.position)
		if distance <= best_distance:
			best = combatant
			best_distance = distance
	return best


func _process_attack(attacker: Combatant, events: Array[Dictionary]) -> void:
	if not attacker.is_alive() or attacker.target_id == -1 or not attacker.can_fight:
		return
	var target: Combatant = _combatants.get(attacker.target_id)
	if target == null or not target.is_alive():
		attacker.target_id = -1
		return
	if tick < attacker.next_attack_tick:
		return
	if _flat_distance(attacker.position, target.position) > attacker.reach:
		return

	var chance := CombatMath.hit_chance(
		attacker.effective_level("attack"), attacker.bonuses["attack"],
		target.effective_level("defence"), target.bonuses["defence"])
	var damage := 0
	if rng.randf() < chance:
		damage = mini(rng.randi_range(1, attacker.max_hit()), target.hp)
	target.hp -= damage
	attacker.next_attack_tick = tick + attacker.attack_speed
	events.append({"type": "hit", "attacker": attacker.id, "target": target.id, "damage": damage, "tick": tick})
	if attacker.skills and damage > 0:
		_award_xp(attacker, Skills.STYLE_SKILLS[attacker.style], damage * Skills.STYLE_XP_PER_DAMAGE, events)
		_award_xp(attacker, "vitality", damage * Skills.VITALITY_XP_PER_DAMAGE, events)

	if target.target_id == -1 and target.auto_retaliate and target.can_fight and not target.returning:
		target.target_id = attacker.id
		# Retaliation lands after half the target's attack speed, not instantly.
		target.next_attack_tick = maxi(target.next_attack_tick, tick + ceili(target.attack_speed / 2.0))
	if not target.is_alive():
		_kill(target, events)


func _award_xp(combatant: Combatant, skill: String, amount: float, events: Array[Dictionary]) -> void:
	var new_level: int = combatant.skills.add_xp(skill, amount)
	events.append({"type": "xp", "id": combatant.id, "skill": skill, "amount": amount, "tick": tick})
	if new_level > 0:
		if skill == "vitality":
			combatant.hp += new_level - combatant.max_hp
			combatant.max_hp = new_level
		events.append({"type": "level_up", "id": combatant.id, "skill": skill, "level": new_level, "tick": tick})


func _kill(victim: Combatant, events: Array[Dictionary]) -> void:
	victim.target_id = -1
	victim.move_target = null
	for combatant in _combatants.values():
		if combatant.target_id == victim.id:
			combatant.target_id = -1
	if victim.respawn_ticks >= 0:
		victim.respawn_at_tick = tick + maxi(victim.respawn_ticks, 1)
	events.append({"type": "death", "id": victim.id, "tick": tick})
	if not victim.drop_table.is_empty():
		var items := Drops.roll(ContentDB.drop_table(victim.drop_table), rng)
		if not items.is_empty():
			events.append({"type": "drop", "id": victim.id, "items": items, "position": victim.position, "tick": tick})
			_add_ground_pile(victim.position, items, events)


func _regenerate() -> void:
	for combatant in _combatants.values():
		if combatant.is_alive() and combatant.hp < combatant.max_hp:
			combatant.hp += 1


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
