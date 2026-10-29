extends RefCounted
## Monster AI and attacks: who chases whom, hit rolls, damage, combat XP, and ammo.

const Combatant := preload("res://scripts/sim/combatant.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const CombatMath := preload("res://scripts/sim/combat_math.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")
const Slayer := preload("res://scripts/sim/slayer.gd")

## The most of a blow a protection blessing can turn aside.
const PROTECT_CAP := 0.8
## Chance per idle tick that a monster wanders somewhere new.
const WANDER_CHANCE := 0.1
## Aggressive monsters ignore players above this multiple of their level.
const AGGRO_LEVEL_MULTIPLIER := 2
## Chance that a fired arrow or sling bullet can be picked up again.
const AMMO_RECOVERY_CHANCE := 0.75
## Monsters give up on targets farther away than this (e.g. who left the area).
const CHASE_RANGE := 30.0
## How long a siren's song holds an unwarded player. Longer than her attack
## speed, so a player who keeps listening never gets a blow in.
const ENTRANCE_TICKS := 6
## The most a basilisk's gaze drains a level, as a share of it.
const PETRIFY_MAX_DRAIN := 0.3
## How much harder a gorgon hits an unwarded player.
const GORGON_DAMAGE := 1.5
## What each kind of weapon special does to the attack it's spent on.
const SPECIAL_EFFECTS := {
	"twin": {"hits": 2},
	"strong": {"accuracy": 1.5, "damage": 1.2},
	"heavy": {"accuracy": 0.9, "damage": 1.5},
	"sure": {"accuracy": 2.0, "damage": 1.1},
	"volley": {"hits": 2},
}

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


## Monster AI: leash, chase, aggro, or wander. Decides where to move; the
## scene does the moving and reports positions back.
func think(monster: Combatant) -> void:
	if not monster.is_alive():
		return
	var from_spawn: float = sim.flat_distance(monster.position, monster.spawn_position)
	if monster.returning:
		if from_spawn <= 1.0:
			monster.returning = false
			monster.move_target = null
		return
	if monster.target_id != -1 and from_spawn > monster.leash_radius:
		_give_up(monster)
		return

	var target: Combatant = sim.get_combatant(monster.target_id)
	if target and sim.flat_distance(monster.position, target.position) > CHASE_RANGE:
		_give_up(monster)
		return
	if target == null and monster.aggressive:
		target = _find_aggro_target(monster)
		if target:
			monster.target_id = target.id
	if target and target.is_alive():
		var in_reach: bool = sim.flat_distance(monster.position, target.position) <= monster.reach * 0.9
		monster.move_target = null if in_reach else target.position
	elif sim.rng.randf() < WANDER_CHANCE:
		var angle: float = sim.rng.randf_range(0.0, TAU)
		var distance: float = sim.rng.randf_range(0.0, monster.wander_radius)
		monster.move_target = monster.spawn_position + Vector3(cos(angle), 0.0, sin(angle)) * distance


func process_attack(attacker: Combatant, events: Array[Dictionary]) -> void:
	if not attacker.is_alive() or attacker.target_id == -1 or not attacker.can_fight:
		return
	var target: Combatant = sim.get_combatant(attacker.target_id)
	if target == null or not target.is_alive():
		attacker.target_id = -1
		return
	var tick: int = sim.tick
	if tick < attacker.next_attack_tick or attacker.stunned_until > tick:
		return
	if sim.flat_distance(attacker.position, target.position) > attacker.attack_range():
		return
	var kind := attacker.combat_kind()
	if attacker.uses_ammo() and not attacker.equipment.has_ammo():
		attacker.target_id = -1
		sim.message(attacker, "You have no suitable ammunition equipped.", events)
		return
	if not meets_slayer_requirement(attacker, target):
		attacker.target_id = -1
		sim.message(attacker, "You need Slayer %d to fight this." % Slayer.required_level(target.monster_id), events)
		return

	if attacker.has_brain and sim.boss.try_throw(attacker, target, events):
		return

	# Monsters with a ward item are much worse to fight without it.
	var effect := ""
	if attacker.is_player() and not target.monster_id.is_empty():
		effect = Slayer.unwarded_effect(target.monster_id, attacker.equipment, attacker.inventory)
	elif target.is_player() and not attacker.monster_id.is_empty():
		effect = Slayer.unwarded_effect(attacker.monster_id, target.equipment, target.inventory)

	var roll: Array = attacker.attack_roll_parts()
	var boost := Slayer.boost(attacker, target)
	var special := _take_special(attacker, events)
	var blow := attacker.attack_type()
	var chance := CombatMath.hit_chance(floori(roll[0] * boost * special.get("accuracy", 1.0)), roll[1],
		target.effective_level("defence"), target.defence_bonus_against(blow))
	var max_damage := floori(attacker.max_hit() * boost * special.get("damage", 1.0))
	# A gorgon's gaze holds an unwarded player still for the blow.
	if effect == "gorgon_gaze" and target.is_player():
		max_damage = floori(max_damage * GORGON_DAMAGE)
	var damage := 0
	var lands: bool = sim.rng.randf() < chance
	if effect in ["drain_vitality", "entrance", "petrify", "gorgon_gaze"] and target.is_player():
		lands = true
	# Silenced: this attack falls on nothing, and the curse is spent.
	if attacker.curses.has("silenced"):
		lands = false
		attacker.curses.erase("silenced")
		events.append({"type": "silenced_miss", "id": attacker.id, "tick": tick})
	if lands and not (effect == "no_damage" and attacker.is_player()):
		damage = mini(protected(target, blow, sim.rng.randi_range(1, max_damage)), target.hp)
	target.hp -= damage
	# Kills by a summoned shade count as its caster's.
	target.last_attacker_id = attacker.summoned_by if attacker.summoned_by != -1 else attacker.id
	if effect == "drain_vitality" and target.is_player():
		attacker.hp = mini(attacker.hp + damage, attacker.max_hp)
	# A basilisk's gaze stiffens an unwarded player's limbs, a level at a time.
	if effect in ["petrify", "gorgon_gaze"] and target.is_player():
		_petrify(target, events)
	# A siren's song holds an unwarded player: they can't strike for a while.
	if effect == "entrance" and target.is_player():
		if tick >= target.entranced_until:
			sim.message(target, "The siren's song holds you! You can't bring yourself to strike.", events)
		target.entranced_until = tick + ENTRANCE_TICKS
		target.next_attack_tick = maxi(target.next_attack_tick, target.entranced_until)
	attacker.next_attack_tick = tick + attacker.current_attack_speed(tick)
	events.append({"type": "hit", "attacker": attacker.id, "target": target.id, "damage": damage,
		"ranged": kind == "ranged", "kind": kind, "tick": tick})
	# A twin thrust or a volley strikes again at once.
	if special.get("hits", 1) > 1 and target.is_alive():
		var second := 0
		if sim.rng.randf() < chance and not (effect == "no_damage" and attacker.is_player()):
			second = mini(protected(target, blow, sim.rng.randi_range(1, max_damage)), target.hp)
		target.hp -= second
		damage += second
		if attacker.uses_ammo():
			_use_ammo(attacker, target.position, events)
		events.append({"type": "hit", "attacker": attacker.id, "target": target.id, "damage": second,
			"ranged": kind == "ranged", "kind": kind, "tick": tick})
	if attacker.is_player():
		sim.quests.on_attack(attacker, target, kind, events)
	var curse: String = attacker.equipment.curse() if kind == "ritus" else ""
	if attacker.uses_ammo():
		_use_ammo(attacker, target.position, events)
	if kind == "ritus" and attacker.is_player():
		sim.pietas.on_curse(attacker, events)
	if lands and target.is_alive() and not curse.is_empty():
		sim.curses.apply(attacker, target, curse, events)
	var credited: Combatant = sim.get_combatant(attacker.summoned_by) if attacker.summoned_by != -1 else attacker
	if credited:
		award_combat_xp(credited, damage, events)

	if target.target_id == -1 and target.auto_retaliate and target.can_fight and not target.returning \
			and meets_slayer_requirement(target, attacker):
		target.target_id = attacker.id
		# Retaliation lands after half the target's attack speed, not instantly.
		target.next_attack_tick = maxi(target.next_attack_tick, tick + ceili(target.attack_speed / 2.0))
	if not target.is_alive():
		sim.kill(target, events)


## A hit after the target's protection blessing against that kind of attack
## (protect_melee and so on): a share of it, rounded, never more than
## PROTECT_CAP, so a protected blow still lands.
static func protected(target: Combatant, kind: String, damage: int) -> int:
	var share: float = minf(target.blessing_boosts.get("protect_" + kind, 0.0), PROTECT_CAP)
	return roundi(damage * (1.0 - share))


## Drains Attack, Strength and Defence by a level each (eating into any
## remedy boost first), down to PETRIFY_MAX_DRAIN of the level and never
## below level 1. Drains
## recover a level a minute, like remedies wear off.
func _petrify(player: Combatant, events: Array) -> void:
	var drained := false
	for skill in ["attack", "strength", "defence"]:
		var floor_amount := -mini(ceili(player.level(skill) * PETRIFY_MAX_DRAIN), player.level(skill) - 1)
		var boost: Dictionary = player.remedy_boosts.get(skill, {"amount": 0, "next_decay": sim.tick + sim.items.REMEDY_DECAY_TICKS})
		if boost["amount"] > floor_amount:
			drained = drained or boost["amount"] >= 0
			boost["amount"] -= 1
		if boost["amount"] == 0:
			player.remedy_boosts.erase(skill)
		else:
			player.remedy_boosts[skill] = boost
	if drained:
		sim.message(player, "The gaze turns your limbs to stone!", events)


## Spends an armed special attack, if the weapon has one and there's
## enough impetus, and returns its effect ({} for a plain attack).
func _take_special(attacker: Combatant, events: Array) -> Dictionary:
	if not attacker.is_player() or not attacker.special_armed:
		return {}
	attacker.special_armed = false
	var special: Dictionary = attacker.equipment.weapon().get("special", {})
	if special.is_empty():
		return {}
	if attacker.impetus < special["cost"]:
		sim.message(attacker, "You need %d impetus for %s." % [special["cost"], special["name"]], events)
		return {}
	attacker.impetus -= special["cost"]
	events.append({"type": "special", "id": attacker.id, "name": special["name"], "tick": sim.tick})
	sim.message(attacker, "%s!" % special["name"].capitalize(), events)
	return SPECIAL_EFFECTS[special["effect"]]


func award_combat_xp(attacker: Combatant, damage: int, events: Array) -> void:
	if not attacker.skills or damage <= 0:
		return
	var style_skills: Array = Skills.STYLE_SKILLS[attacker.style]
	for skill in style_skills:
		sim.award_xp(attacker, skill, damage * Skills.STYLE_XP_PER_DAMAGE / style_skills.size(), events)
	sim.award_xp(attacker, "vitality", damage * Skills.VITALITY_XP_PER_DAMAGE, events)


func meets_slayer_requirement(fighter: Combatant, opponent: Combatant) -> bool:
	if not fighter.is_player() or opponent.monster_id.is_empty():
		return true
	return fighter.skills.level("slayer") >= Slayer.required_level(opponent.monster_id)


func _give_up(monster: Combatant) -> void:
	monster.target_id = -1
	monster.returning = true
	monster.move_target = monster.spawn_position


func _find_aggro_target(monster: Combatant) -> Combatant:
	var best: Combatant = null
	var best_distance := monster.aggro_radius
	for combatant: Combatant in sim.combatants():
		if not combatant.is_player() or not combatant.is_alive():
			continue
		if combatant.combat_level() > monster.display_level * AGGRO_LEVEL_MULTIPLIER:
			continue
		var distance: float = sim.flat_distance(monster.position, combatant.position)
		if distance <= best_distance:
			best = combatant
			best_distance = distance
	return best


## Each shot uses one ammo; most of it lands near the target to pick up.
func _use_ammo(attacker: Combatant, at: Vector3, events: Array[Dictionary]) -> void:
	var equipment: RefCounted = attacker.equipment
	var ammo: String = equipment.worn["ammo"]
	equipment.ammo_count -= 1
	if equipment.ammo_count <= 0:
		equipment.take_off("ammo")
		attacker.apply_equipment()
		sim.message(attacker, "That was your last %s." % ContentDB.item(ammo)["name"].to_lower(), events)
	events.append({"type": "equipment_changed", "id": attacker.id, "tick": sim.tick})
	# Tablets are spent for good; arrows and bullets can be found again.
	if attacker.is_ranged() and sim.rng.randf() < AMMO_RECOVERY_CHANCE:
		sim.items.drop_near(at, ammo, 1, events)
