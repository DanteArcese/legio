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


## Advances one tick and returns the events that happened during it.
func step() -> Array[Dictionary]:
	tick += 1
	var events: Array[Dictionary] = []
	_apply_commands()
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


func _apply_commands() -> void:
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


func _regenerate() -> void:
	for combatant in _combatants.values():
		if combatant.is_alive() and combatant.hp < combatant.max_hp:
			combatant.hp += 1


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
