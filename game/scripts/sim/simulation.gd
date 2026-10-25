extends RefCounted
## Deterministic, tick-based game logic.
##
## Nothing here touches scene nodes. The client queues commands and feeds in
## positions. step() advances one tick and returns events for the client to
## render. With the same seed and inputs, the same events come out, which
## keeps the logic testable and lets it move to a server later.

const Combatant := preload("res://scripts/sim/combatant.gd")

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
		_process_attack(_combatants[id], events)
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


func _process_respawns(events: Array[Dictionary]) -> void:
	for combatant in _combatants.values():
		if combatant.respawn_at_tick == tick:
			combatant.hp = combatant.max_hp
			combatant.respawn_at_tick = -1
			events.append({"type": "respawn", "id": combatant.id, "tick": tick})


func _process_attack(attacker: Combatant, events: Array[Dictionary]) -> void:
	if not attacker.is_alive() or attacker.target_id == -1 or not attacker.can_attack():
		return
	var target: Combatant = _combatants.get(attacker.target_id)
	if target == null or not target.is_alive():
		attacker.target_id = -1
		return
	if tick < attacker.next_attack_tick:
		return
	if attacker.position.distance_to(target.position) > attacker.reach:
		return

	var damage := 0
	if rng.randf() < attacker.accuracy:
		damage = mini(rng.randi_range(1, attacker.max_hit), target.hp)
	target.hp -= damage
	attacker.next_attack_tick = tick + attacker.attack_speed
	events.append({"type": "hit", "attacker": attacker.id, "target": target.id, "damage": damage, "tick": tick})

	if target.target_id == -1 and target.auto_retaliate and target.can_attack():
		target.target_id = attacker.id
		# Retaliation lands after half the target's attack speed, not instantly.
		target.next_attack_tick = maxi(target.next_attack_tick, tick + ceili(target.attack_speed / 2.0))
	if not target.is_alive():
		_kill(target, events)


func _kill(victim: Combatant, events: Array[Dictionary]) -> void:
	victim.target_id = -1
	for combatant in _combatants.values():
		if combatant.target_id == victim.id:
			combatant.target_id = -1
	if victim.respawn_ticks >= 0:
		victim.respawn_at_tick = tick + maxi(victim.respawn_ticks, 1)
	events.append({"type": "death", "id": victim.id, "tick": tick})
