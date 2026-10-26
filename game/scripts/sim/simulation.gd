extends RefCounted
## Deterministic, tick-based game logic.
##
## Nothing here touches scene nodes. The client queues commands and feeds in
## positions. step() advances one tick and returns events for the client to
## render. With the same seed and inputs, the same events come out, which
## keeps the logic testable and lets it move to a server later.
##
## This script owns the combatants, the command queue, and the tick order.
## The systems live in modules: items, combat, curses, graves, skilling, pietas, quests, and thieving.

const Combatant := preload("res://scripts/sim/combatant.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const Drops := preload("res://scripts/sim/drops.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")
const ItemContainer := preload("res://scripts/sim/item_container.gd")
const Equipment := preload("res://scripts/sim/equipment.gd")
const Slayer := preload("res://scripts/sim/slayer.gd")
const Items := preload("res://scripts/sim/items.gd")
const Combat := preload("res://scripts/sim/combat.gd")
const Curses := preload("res://scripts/sim/curses.gd")
const Graves := preload("res://scripts/sim/graves.gd")
const Skilling := preload("res://scripts/sim/skilling.gd")
const Pietas := preload("res://scripts/sim/pietas.gd")
const Quests := preload("res://scripts/sim/quests.gd")
const Thieving := preload("res://scripts/sim/thieving.gd")

const INVENTORY_SIZE := 28
const BANK_SIZE := 400
const VENATOR_RANGE := 3.0
const PLAYER_RESPAWN_TICKS := 3
## Where items can come from. Solitarius accounts refuse the restricted ones.
const SOLITARIUS_BLOCKED_SOURCES := ["market", "trade"]
## Every combatant regains 1 HP this often.
const REGEN_INTERVAL := 100

var tick := 0
var rng := RandomNumberGenerator.new()
var items := Items.new(self)
var combat := Combat.new(self)
var curses := Curses.new(self)
var graves := Graves.new(self)
var skilling := Skilling.new(self)
var pietas := Pietas.new(self)
var quests := Quests.new(self)
var thieving := Thieving.new(self)
## player id -> items held by the libitinarii, waiting to be reclaimed.
var reclaimable := {}

var _combatants := {}
var _pending_commands: Array[Dictionary] = []
## venator id -> position
var _venators := {}


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
	items.banks.append(position)


func add_libitinarius(position: Vector3) -> void:
	graves.libitinarii.append(position)


func add_venator(venator_id: String, position: Vector3) -> void:
	_venators[venator_id] = position


func add_shopkeeper(shop_id: String, position: Vector3) -> void:
	items.shopkeepers[shop_id] = position


## Recreates a grave from a save, with the time it had left.
func restore_grave(player_id: int, position: Vector3, grave_items: Array, ticks_left: int) -> void:
	graves.restore(player_id, position, grave_items, ticks_left)


func grave_of(player_id: int) -> Dictionary:
	return graves.grave_of(player_id)


func ground_piles() -> Array:
	return items.ground.values()


## The single path for items entering a player's inventory. Applies account
## mode rules, and drops whatever doesn't fit on the ground at the player's
## feet. Returns how many reached the inventory.
func give_item(id: int, item_id: String, quantity: int, source: String, events: Array) -> int:
	var player: Combatant = _combatants[id]
	if player.account_mode == "solitarius" and source in SOLITARIUS_BLOCKED_SOURCES:
		message(player, "As a Solitarius, you stand alone.", events)
		return 0
	var added: int = player.inventory.add(item_id, quantity)
	if added < quantity:
		items.add_ground_pile(player.position, [{"item": item_id, "quantity": quantity - added}], events)
	if added > 0:
		events.append({"type": "inventory_changed", "id": id, "tick": tick})
	return added


func get_combatant(id: int) -> Combatant:
	return _combatants.get(id)


func combatants() -> Array:
	return _combatants.values()


## Combatant ids in ascending order. Processing in this order keeps RNG use,
## and therefore every outcome, deterministic.
func sorted_ids() -> Array:
	var ids := _combatants.keys()
	ids.sort()
	return ids


func set_position(id: int, position: Vector3) -> void:
	_combatants[id].position = position


## Takes a combatant out of the simulation, clearing anyone's aim at it.
func remove_combatant(id: int) -> void:
	_combatants.erase(id)
	for combatant in _combatants.values():
		if combatant.target_id == id:
			combatant.target_id = -1


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
	items.expire_ground(events)
	graves.expire(events)
	_process_respawns(events)
	var ids := sorted_ids()
	for id in ids:
		var combatant: Combatant = _combatants[id]
		if combatant.has_brain:
			combat.think(combatant)
	curses.process_summons(events)
	for id in ids:
		if _combatants.has(id):
			combat.process_attack(_combatants[id], events)
	curses.process(events)
	var players := ids.filter(func(i): return _combatants.has(i)).map(func(i): return _combatants[i]) \
		.filter(func(c): return c.inventory != null)
	skilling.process(players, events)
	pietas.process(players, events)
	quests.process(players, events)
	thieving.process(events)
	if tick % REGEN_INTERVAL == 0:
		_regenerate()
	return events


func award_xp(combatant: Combatant, skill: String, amount: float, events: Array) -> void:
	var new_level: int = combatant.skills.add_xp(skill, amount)
	events.append({"type": "xp", "id": combatant.id, "skill": skill, "amount": amount, "tick": tick})
	if new_level > 0:
		if skill == "vitality":
			combatant.hp += new_level - combatant.max_hp
			combatant.max_hp = new_level
		elif skill == "pietas":
			combatant.favour += 1.0
		events.append({"type": "level_up", "id": combatant.id, "skill": skill, "level": new_level, "tick": tick})


func message(player: Combatant, text: String, events: Array) -> void:
	events.append({"type": "message", "id": player.id, "text": text, "tick": tick})


func kill(victim: Combatant, events: Array[Dictionary]) -> void:
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
		graves.on_player_death(victim, events)
	var killer: Combatant = _combatants.get(victim.last_attacker_id)
	if killer and killer.is_player() and not victim.monster_id.is_empty():
		_slayer_kill(killer, victim, events)
		quests.on_kill(killer, victim, events)
	victim.last_attacker_id = -1
	if not victim.drop_table.is_empty():
		var dropped := Drops.roll(ContentDB.drop_table(victim.drop_table), rng)
		if not dropped.is_empty():
			events.append({"type": "drop", "id": victim.id, "items": dropped, "position": victim.position, "tick": tick})
			# Join a pile already lying here, so repeat kills don't litter the ground.
			for entry in dropped:
				items.drop_near(victim.position, entry["item"], entry["quantity"], events)


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


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
					_apply_player_command(actor, command, events)


func _apply_player_command(player: Combatant, command: Dictionary, events: Array[Dictionary]) -> void:
	match command["type"]:
		"loot_grave":
			graves.loot(player, events)
		"reclaim":
			graves.reclaim(player, events)
		"slayer_task":
			_slayer_task(player, command.get("venator", ""), events)
		"talk":
			quests.talk(player, command.get("npc", ""), events)
		"steal":
			thieving.steal(player, command.get("stall", -1), events)
		"pickpocket":
			thieving.pickpocket(player, command.get("mark", -1), events)
		"mine":
			skilling.start_mining(player, command.get("rock", -1), events)
		"chop":
			skilling.start_chopping(player, command.get("tree", -1), events)
		"fish":
			skilling.start_fishing(player, command.get("spot", -1), events)
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
		"wash":
			pietas.start_washing(player, events)
		"cleanse":
			pietas.cleanse(player, events)
		_:
			items.apply_command(player, command, events)


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


func _slayer_task(player: Combatant, venator_id: String, events: Array[Dictionary]) -> void:
	if not _venators.has(venator_id) or flat_distance(_venators[venator_id], player.position) > VENATOR_RANGE:
		return
	var task := player.slayer_task
	if not task.is_empty():
		message(player, "You still need to hunt %d %s." % [task["remaining"], Slayer.plural_name(task["monster"])], events)
		return
	task = Slayer.assign(venator_id, player.combat_level(), player.skills.level("slayer"), rng)
	if task.is_empty():
		message(player, "Come back when you can handle yourself.", events)
		return
	player.slayer_task = task
	message(player, "Hunt %d %s." % [task["total"], Slayer.plural_name(task["monster"])], events)
	events.append({"type": "slayer_assigned", "id": player.id, "task": task.duplicate(), "tick": tick})


## Kill credit: Slayer XP equals the monster's hitpoints, on task only.
func _slayer_kill(player: Combatant, victim: Combatant, events: Array[Dictionary]) -> void:
	var task := player.slayer_task
	if task.is_empty() or task["monster"] != victim.monster_id:
		return
	task["remaining"] -= 1
	award_xp(player, "slayer", victim.max_hp, events)
	events.append({"type": "slayer_progress", "id": player.id, "remaining": task["remaining"], "tick": tick})
	if task["remaining"] > 0:
		return
	var points: int = ContentDB.venator(task["venator"])["points_per_task"]
	player.slayer_points += points
	player.slayer_tasks_done += 1
	player.slayer_task = {}
	message(player, "Contract complete! You earn %d Slayer points (%d total)." % [points, player.slayer_points], events)
	events.append({"type": "slayer_complete", "id": player.id, "points": points, "tick": tick})


func _regenerate() -> void:
	for combatant in _combatants.values():
		if combatant.is_alive() and combatant.hp < combatant.max_hp:
			combatant.hp += 1
