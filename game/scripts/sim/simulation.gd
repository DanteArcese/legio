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
const DeathRules := preload("res://scripts/sim/death_rules.gd")
const Slayer := preload("res://scripts/sim/slayer.gd")
const Skilling := preload("res://scripts/sim/skilling.gd")
const Pietas := preload("res://scripts/sim/pietas.gd")

const INVENTORY_SIZE := 28
const BANK_SIZE := 400
## Ground items disappear after this many ticks (2 minutes).
const GROUND_LIFETIME := 200
const PICKUP_RANGE := 2.0
const BANK_RANGE := 3.0
const GRAVE_RANGE := 2.0
const LIBITINARIUS_RANGE := 3.0
const VENATOR_RANGE := 3.0
## Graves last 15 minutes before the libitinarii collect the items.
const GRAVE_LIFETIME := 1500
const PLAYER_RESPAWN_TICKS := 3
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
## Drops this close to an existing pile join it.
const PILE_MERGE_RADIUS := 1.5
## Chance that a fired arrow or sling bullet can be picked up again.
const AMMO_RECOVERY_CHANCE := 0.75
## Binding: chance per landed curse, and how long the target stays slowed.
const BINDING_CHANCE := 0.6
const BINDING_TICKS := 10
## Withering: damage every few ticks, a set number of times.
const WITHERING_INTERVAL := 3
const WITHERING_PULSES := 5
## Monsters give up on targets farther away than this (e.g. who left the area).
const CHASE_RANGE := 30.0

var tick := 0
var rng := RandomNumberGenerator.new()
var skilling := Skilling.new(self)
var pietas := Pietas.new(self)

var _combatants := {}
var _pending_commands: Array[Dictionary] = []
## pile id -> {"id", "position", "items", "expires_at"}
var _ground := {}
var _next_pile_id := 1
var _banks: Array[Vector3] = []
var _libitinarii: Array[Vector3] = []
## venator id -> position
var _venators := {}
## shop id -> shopkeeper position
var _shopkeepers := {}
## player id -> {"id", "position", "items", "expires_at"}. One grave per player.
var _graves := {}
var _next_grave_id := 1
## player id -> items held by the libitinarii, waiting to be reclaimed.
var reclaimable := {}


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
	player.spawn_position = position
	player.respawn_ticks = PLAYER_RESPAWN_TICKS
	player.apply_equipment()
	return player


func give_starting_kit(id: int) -> void:
	for entry in ContentDB.starting_kit():
		give_item(id, entry["item"], entry["quantity"], "starting_kit", [])


func add_bank(position: Vector3) -> void:
	_banks.append(position)


func add_libitinarius(position: Vector3) -> void:
	_libitinarii.append(position)


func add_venator(venator_id: String, position: Vector3) -> void:
	_venators[venator_id] = position


func add_shopkeeper(shop_id: String, position: Vector3) -> void:
	_shopkeepers[shop_id] = position


## Recreates a grave from a save, with the time it had left.
func restore_grave(player_id: int, position: Vector3, items: Array, ticks_left: int) -> void:
	_graves[player_id] = {"id": _next_grave_id, "position": position, "items": items, "expires_at": tick + maxi(ticks_left, 1)}
	_next_grave_id += 1


func grave_of(player_id: int) -> Dictionary:
	return _graves.get(player_id, {})


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
	_expire_graves(events)
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
	_process_curses(events)
	var players := ids.map(func(i): return _combatants[i]).filter(func(c): return c.inventory != null)
	skilling.process(players, events)
	pietas.process(players, events)
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
					if actor.inventory:
						skilling.stop(actor, events)
			"stop":
				actor.target_id = -1
			"style":
				var allowed: Array = Skills.styles_for(actor.combat_kind())
				if not actor.skills or command["style"] in allowed:
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
			if Equipment.slot_of(slot["item"]) == "ammo":
				_equip_ammo(player, slot_index, events)
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
			var quantity: int = player.equipment.ammo_count if command["equip_slot"] == "ammo" else 1
			if player.inventory.space_for(item_id, quantity) < quantity:
				_message(player, "You don't have enough inventory space.", events)
				return
			player.equipment.take_off(command["equip_slot"])
			player.inventory.add(item_id, quantity)
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
			_pickup(player, command.get("pile", -1), command.get("item", ""), events)
		"loot_grave":
			_loot_grave(player, events)
		"reclaim":
			_reclaim(player, events)
		"slayer_task":
			_slayer_task(player, command.get("venator", ""), events)
		"buy":
			_buy(player, command.get("shop", ""), command.get("item", ""), events)
		"mine":
			skilling.start_mining(player, command.get("rock", -1), events)
		"craft":
			skilling.start_craft(player, command.get("kind", ""), command.get("recipe", ""), command.get("count", 1), events)
		"stop_action":
			skilling.stop(player, events)
		"bless":
			pietas.toggle(player, command.get("blessing", ""), events)
		"pray":
			pietas.pray(player, events)
		"offer":
			pietas.start_offering(player, command.get("item", ""), events)
		"deposit", "deposit_all", "withdraw":
			if not _near_bank(player):
				_message(player, "You need to be at a bank.", events)
				return
			_bank_command(player, command, slot, events)


## Ammo is worn as a whole stack. Wearing more of the same kind adds to it;
## a different kind swaps places with the worn stack.
func _equip_ammo(player: Combatant, slot_index: int, events: Array[Dictionary]) -> void:
	var slot: Dictionary = player.inventory.take_slot(slot_index)
	var equipment: RefCounted = player.equipment
	if equipment.worn["ammo"] == slot["item"]:
		equipment.ammo_count += slot["quantity"]
	else:
		var previous: String = equipment.worn["ammo"]
		var previous_count: int = equipment.ammo_count
		equipment.worn["ammo"] = slot["item"]
		equipment.ammo_count = slot["quantity"]
		if not previous.is_empty():
			player.inventory.slots[slot_index] = {"item": previous, "quantity": previous_count}
	_equipment_changed(player, events)


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


func _message(player: Combatant, text: String, events: Array) -> void:
	events.append({"type": "message", "id": player.id, "text": text, "tick": tick})


func _near_bank(player: Combatant) -> bool:
	return _banks.any(func(bank): return _flat_distance(bank, player.position) <= BANK_RANGE)


## Takes everything from a pile, or only one item id when item_id is set.
func _pickup(player: Combatant, pile_id: int, item_id: String, events: Array[Dictionary]) -> void:
	var pile: Dictionary = _ground.get(pile_id, {})
	if pile.is_empty() or _flat_distance(pile["position"], player.position) > PICKUP_RANGE:
		return
	var remaining := []
	var took_any := false
	for entry in pile["items"]:
		if not item_id.is_empty() and entry["item"] != item_id:
			remaining.append(entry)
			continue
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
		var stuck := remaining.any(func(entry): return item_id.is_empty() or entry["item"] == item_id)
		pile["items"] = remaining
		events.append({"type": "ground_update", "pile": pile_id, "items": remaining, "tick": tick})
		if stuck:
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
			if combatant.has_brain or combatant.is_player():
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
	if target and _flat_distance(monster.position, target.position) > CHASE_RANGE:
		monster.target_id = -1
		monster.returning = true
		monster.move_target = monster.spawn_position
		return
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
	if _flat_distance(attacker.position, target.position) > attacker.attack_range():
		return
	var kind := attacker.combat_kind()
	if attacker.uses_ammo() and not attacker.equipment.has_ammo():
		attacker.target_id = -1
		_message(attacker, "You have no suitable ammunition equipped.", events)
		return
	if not _meets_slayer_requirement(attacker, target):
		attacker.target_id = -1
		_message(attacker, "You need Slayer %d to fight this." % Slayer.required_level(target.monster_id), events)
		return

	# Monsters with a ward item are much worse to fight without it.
	var effect := ""
	if attacker.is_player() and not target.monster_id.is_empty():
		effect = Slayer.unwarded_effect(target.monster_id, attacker.equipment)
	elif target.is_player() and not attacker.monster_id.is_empty():
		effect = Slayer.unwarded_effect(attacker.monster_id, target.equipment)

	var roll: Array = attacker.attack_roll_parts()
	var chance := CombatMath.hit_chance(roll[0], roll[1], target.effective_level("defence"), target.defence_bonus_against(kind))
	var damage := 0
	var lands := rng.randf() < chance
	if effect == "drain_vitality" and target.is_player():
		lands = true
	if lands and not (effect == "no_damage" and attacker.is_player()):
		damage = mini(rng.randi_range(1, attacker.max_hit()), target.hp)
	target.hp -= damage
	target.last_attacker_id = attacker.id
	if effect == "drain_vitality" and target.is_player():
		attacker.hp = mini(attacker.hp + damage, attacker.max_hp)
	attacker.next_attack_tick = tick + attacker.current_attack_speed(tick)
	events.append({"type": "hit", "attacker": attacker.id, "target": target.id, "damage": damage,
		"ranged": kind == "ranged", "kind": kind, "tick": tick})
	var curse: String = attacker.equipment.curse() if kind == "ritus" else ""
	if attacker.uses_ammo():
		_use_ammo(attacker, target.position, events)
	if lands and target.is_alive() and not curse.is_empty():
		_apply_curse(attacker, target, curse, events)
	_award_combat_xp(attacker, damage, events)

	if target.target_id == -1 and target.auto_retaliate and target.can_fight and not target.returning \
			and _meets_slayer_requirement(target, attacker):
		target.target_id = attacker.id
		# Retaliation lands after half the target's attack speed, not instantly.
		target.next_attack_tick = maxi(target.next_attack_tick, tick + ceili(target.attack_speed / 2.0))
	if not target.is_alive():
		_kill(target, events)


func _award_combat_xp(attacker: Combatant, damage: int, events: Array) -> void:
	if not attacker.skills or damage <= 0:
		return
	var style_skills: Array = Skills.STYLE_SKILLS[attacker.style]
	for skill in style_skills:
		_award_xp(attacker, skill, damage * Skills.STYLE_XP_PER_DAMAGE / style_skills.size(), events)
	_award_xp(attacker, "vitality", damage * Skills.VITALITY_XP_PER_DAMAGE, events)


func _apply_curse(caster: Combatant, target: Combatant, curse: String, events: Array[Dictionary]) -> void:
	var until := tick
	match curse:
		"binding":
			if rng.randf() >= BINDING_CHANCE + caster.blessing_boosts.get("binding_chance", 0.0):
				return
			until = tick + BINDING_TICKS
			target.curses["bound"] = until
		"withering":
			until = tick + WITHERING_INTERVAL * WITHERING_PULSES
			var damage := 1 + floori(caster.level("ritus") / 25.0) + int(caster.blessing_boosts.get("withering_damage", 0))
			target.curses["withering"] = {"until": until, "next": tick + WITHERING_INTERVAL, "damage": damage, "source": caster.id}
	events.append({"type": "curse", "id": target.id, "curse": curse, "until": until, "source": caster.id, "tick": tick})


## Withering pulses, and expired curses falling away.
func _process_curses(events: Array[Dictionary]) -> void:
	var ids := _combatants.keys()
	ids.sort()
	for id in ids:
		var victim: Combatant = _combatants[id]
		if victim.curses.is_empty():
			continue
		if not victim.is_alive():
			victim.curses.clear()
			continue
		if victim.curses.get("bound", tick) <= tick:
			victim.curses.erase("bound")
		var wither: Dictionary = victim.curses.get("withering", {})
		if wither.is_empty():
			continue
		if tick >= wither["next"]:
			wither["next"] = tick + WITHERING_INTERVAL
			var damage := mini(wither["damage"], victim.hp)
			victim.hp -= damage
			var caster: Combatant = _combatants.get(wither["source"])
			if caster:
				victim.last_attacker_id = caster.id
			events.append({"type": "hit", "attacker": wither["source"], "target": victim.id, "damage": damage,
				"ranged": false, "kind": "withering", "tick": tick})
			if caster:
				_award_combat_xp(caster, damage, events)
			if not victim.is_alive():
				_kill(victim, events)
				continue
		if tick >= wither["until"]:
			victim.curses.erase("withering")


## Each shot uses one ammo; most of it lands near the target to pick up.
func _use_ammo(attacker: Combatant, at: Vector3, events: Array[Dictionary]) -> void:
	var equipment: RefCounted = attacker.equipment
	var ammo: String = equipment.worn["ammo"]
	equipment.ammo_count -= 1
	if equipment.ammo_count <= 0:
		equipment.take_off("ammo")
		attacker.apply_equipment()
		_message(attacker, "That was your last %s." % ContentDB.item(ammo)["name"].to_lower(), events)
	events.append({"type": "equipment_changed", "id": attacker.id, "tick": tick})
	# Tablets are spent for good; arrows and bullets can be found again.
	if attacker.is_ranged() and rng.randf() < AMMO_RECOVERY_CHANCE:
		_drop_near(at, ammo, 1, events)


## Adds items to a pile within MERGE_RADIUS of position, or starts a new one.
func _drop_near(position: Vector3, item_id: String, quantity: int, events: Array) -> void:
	for pile in _ground.values():
		if _flat_distance(pile["position"], position) <= PILE_MERGE_RADIUS:
			var merged := false
			for entry in pile["items"]:
				if entry["item"] == item_id:
					entry["quantity"] += quantity
					merged = true
			if not merged:
				pile["items"].append({"item": item_id, "quantity": quantity})
			pile["expires_at"] = tick + GROUND_LIFETIME
			events.append({"type": "ground_update", "pile": pile["id"], "items": pile["items"], "tick": tick})
			return
	_add_ground_pile(position, [{"item": item_id, "quantity": quantity}], events)


## Public helpers for sim modules (skilling).
func award_xp(combatant: Combatant, skill: String, amount: float, events: Array) -> void:
	_award_xp(combatant, skill, amount, events)


func message(player: Combatant, text: String, events: Array) -> void:
	_message(player, text, events)


func _award_xp(combatant: Combatant, skill: String, amount: float, events: Array) -> void:
	var new_level: int = combatant.skills.add_xp(skill, amount)
	events.append({"type": "xp", "id": combatant.id, "skill": skill, "amount": amount, "tick": tick})
	if new_level > 0:
		if skill == "vitality":
			combatant.hp += new_level - combatant.max_hp
			combatant.max_hp = new_level
		elif skill == "pietas":
			combatant.favour += 1.0
		events.append({"type": "level_up", "id": combatant.id, "skill": skill, "level": new_level, "tick": tick})


func _kill(victim: Combatant, events: Array[Dictionary]) -> void:
	victim.curses.clear()
	victim.target_id = -1
	victim.move_target = null
	for combatant in _combatants.values():
		if combatant.target_id == victim.id:
			combatant.target_id = -1
	if victim.respawn_ticks >= 0:
		victim.respawn_at_tick = tick + maxi(victim.respawn_ticks, 1)
	events.append({"type": "death", "id": victim.id, "tick": tick})
	if victim.inventory:
		_player_death(victim, events)
	var killer: Combatant = _combatants.get(victim.last_attacker_id)
	if killer and killer.is_player() and not victim.monster_id.is_empty():
		_slayer_kill(killer, victim, events)
	victim.last_attacker_id = -1
	if not victim.drop_table.is_empty():
		var items := Drops.roll(ContentDB.drop_table(victim.drop_table), rng)
		if not items.is_empty():
			events.append({"type": "drop", "id": victim.id, "items": items, "position": victim.position, "tick": tick})
			# Join a pile already lying here, so repeat kills don't litter the ground.
			for entry in items:
				_drop_near(victim.position, entry["item"], entry["quantity"], events)


## Keep the most valuable items; the rest go to a grave at the death spot.
## A previous grave still standing goes straight to the libitinarii.
func _player_death(player: Combatant, events: Array[Dictionary]) -> void:
	var split := DeathRules.split(player.inventory, player.equipment)
	for slot in Equipment.SLOTS:
		if not split["kept_worn"].has(slot):
			player.equipment.take_off(slot)
	player.inventory.slots.fill(null)
	for entry in split["kept_inventory"]:
		player.inventory.add(entry["item"], entry["quantity"])
	player.apply_equipment()
	events.append({"type": "inventory_changed", "id": player.id, "tick": tick})
	events.append({"type": "equipment_changed", "id": player.id, "tick": tick})
	if _graves.has(player.id):
		_send_to_libitinarii(player.id, events)
	var lost: Array = DeathRules.merge(split["lost"])
	if lost.is_empty():
		return
	var grave := {"id": _next_grave_id, "position": player.position, "items": lost, "expires_at": tick + GRAVE_LIFETIME}
	_next_grave_id += 1
	_graves[player.id] = grave
	_message(player, "You keep your %d most valuable items. The rest lie in your grave for %d minutes." % [
		DeathRules.KEPT_ON_DEATH, roundi(GRAVE_LIFETIME * 0.6 / 60.0)], events)
	events.append({"type": "grave_add", "id": player.id, "grave": grave["id"], "position": grave["position"],
		"items": lost, "expires_at": grave["expires_at"], "tick": tick})


func _loot_grave(player: Combatant, events: Array[Dictionary]) -> void:
	var grave: Dictionary = _graves.get(player.id, {})
	if grave.is_empty() or _flat_distance(grave["position"], player.position) > GRAVE_RANGE:
		return
	var remaining := []
	for entry in grave["items"]:
		var added: int = player.inventory.add(entry["item"], entry["quantity"])
		if added < entry["quantity"]:
			remaining.append({"item": entry["item"], "quantity": entry["quantity"] - added})
	events.append({"type": "inventory_changed", "id": player.id, "tick": tick})
	if remaining.is_empty():
		_graves.erase(player.id)
		events.append({"type": "grave_remove", "id": player.id, "grave": grave["id"], "tick": tick})
		_message(player, "You recover your belongings.", events)
	else:
		grave["items"] = remaining
		_message(player, "You don't have enough inventory space.", events)


func _expire_graves(events: Array[Dictionary]) -> void:
	for player_id in _graves.keys():
		if _graves[player_id]["expires_at"] <= tick:
			_send_to_libitinarii(player_id, events)


func _send_to_libitinarii(player_id: int, events: Array[Dictionary]) -> void:
	var grave: Dictionary = _graves[player_id]
	_graves.erase(player_id)
	reclaimable[player_id] = DeathRules.merge(reclaimable.get(player_id, []) + grave["items"])
	events.append({"type": "grave_remove", "id": player_id, "grave": grave["id"], "tick": tick})
	events.append({"type": "message", "id": player_id,
		"text": "The libitinarii have collected your belongings from your grave.", "tick": tick})


## Pay the libitinarii to return held items to the bank. Coins come from
## the inventory first, then the bank.
func _reclaim(player: Combatant, events: Array[Dictionary]) -> void:
	if not _libitinarii.any(func(at): return _flat_distance(at, player.position) <= LIBITINARIUS_RANGE):
		return
	var items: Array = reclaimable.get(player.id, [])
	if items.is_empty():
		_message(player, "The libitinarius has nothing of yours.", events)
		return
	var fee := DeathRules.reclaim_fee(items)
	var coins: int = player.inventory.count("coins") + player.bank.count("coins")
	if coins < fee:
		_message(player, "The libitinarius wants %d denarii to return your belongings." % fee, events)
		return
	var from_inventory: int = player.inventory.remove("coins", fee)
	player.bank.remove("coins", fee - from_inventory)
	for entry in items:
		player.bank.add(entry["item"], entry["quantity"])
	reclaimable.erase(player.id)
	_message(player, "You pay %d denarii. Your belongings are waiting in your bank." % fee, events)
	events.append({"type": "inventory_changed", "id": player.id, "tick": tick})
	events.append({"type": "bank_changed", "id": player.id, "tick": tick})


## Buys from a shopkeeper with coins from the inventory.
func _buy(player: Combatant, shop_id: String, item_id: String, events: Array[Dictionary]) -> void:
	if not _shopkeepers.has(shop_id) or _flat_distance(_shopkeepers[shop_id], player.position) > VENATOR_RANGE:
		return
	var offers: Array = ContentDB.shop(shop_id).get("offers", []).filter(func(o): return o["item"] == item_id)
	if offers.is_empty():
		return
	var price: int = offers[0]["price"]
	var quantity: int = offers[0].get("quantity", 1)
	if player.inventory.count("coins") < price:
		_message(player, "You need %d denarii for that." % price, events)
		return
	if player.inventory.space_for(item_id, quantity) < quantity and player.inventory.count("coins") > price:
		_message(player, "You don't have enough inventory space.", events)
		return
	player.inventory.remove("coins", price)
	give_item(player.id, item_id, quantity, "shop", events)
	var name: String = ContentDB.item(item_id)["name"].to_lower()
	_message(player, "You buy %s." % (("a " + name) if quantity == 1 else "%d %s" % [quantity, name]), events)


func _meets_slayer_requirement(fighter: Combatant, opponent: Combatant) -> bool:
	if not fighter.is_player() or opponent.monster_id.is_empty():
		return true
	return fighter.skills.level("slayer") >= Slayer.required_level(opponent.monster_id)


func _slayer_task(player: Combatant, venator_id: String, events: Array[Dictionary]) -> void:
	if not _venators.has(venator_id) or _flat_distance(_venators[venator_id], player.position) > VENATOR_RANGE:
		return
	var task := player.slayer_task
	if not task.is_empty():
		_message(player, "You still need to hunt %d %s." % [task["remaining"], Slayer.plural_name(task["monster"])], events)
		return
	task = Slayer.assign(venator_id, player.combat_level(), player.skills.level("slayer"), rng)
	if task.is_empty():
		_message(player, "Come back when you can handle yourself.", events)
		return
	player.slayer_task = task
	_message(player, "Hunt %d %s." % [task["total"], Slayer.plural_name(task["monster"])], events)
	events.append({"type": "slayer_assigned", "id": player.id, "task": task.duplicate(), "tick": tick})


## Kill credit: Slayer XP equals the monster's hitpoints, on task only.
func _slayer_kill(player: Combatant, victim: Combatant, events: Array[Dictionary]) -> void:
	var task := player.slayer_task
	if task.is_empty() or task["monster"] != victim.monster_id:
		return
	task["remaining"] -= 1
	_award_xp(player, "slayer", victim.max_hp, events)
	events.append({"type": "slayer_progress", "id": player.id, "remaining": task["remaining"], "tick": tick})
	if task["remaining"] > 0:
		return
	var points: int = ContentDB.venator(task["venator"])["points_per_task"]
	player.slayer_points += points
	player.slayer_tasks_done += 1
	player.slayer_task = {}
	_message(player, "Contract complete! You earn %d Slayer points (%d total)." % [points, player.slayer_points], events)
	events.append({"type": "slayer_complete", "id": player.id, "points": points, "tick": tick})


func _regenerate() -> void:
	for combatant in _combatants.values():
		if combatant.is_alive() and combatant.hp < combatant.max_hp:
			combatant.hp += 1


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
