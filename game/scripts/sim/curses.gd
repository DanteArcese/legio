extends RefCounted
## Ritus curses (binding, withering, silencing) and the shades raised by
## Calling the Manes.

const Combatant := preload("res://scripts/sim/combatant.gd")

## Binding: chance per landed curse, and how long the target stays slowed.
const BINDING_CHANCE := 0.6
const BINDING_TICKS := 10
## Withering: damage every few ticks, a set number of times.
const WITHERING_INTERVAL := 3
const WITHERING_PULSES := 5
## Calling the Manes: a shade fights for its caster for a while.
const SHADE_ID_BASE := 100000
const SHADE_LIFETIME := 30
const SHADE_STEP := 1.6
const SHADE_LEVEL_SCALE := 0.8

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


func apply(caster: Combatant, target: Combatant, curse: String, events: Array[Dictionary]) -> void:
	var tick: int = sim.tick
	var until := tick
	match curse:
		"binding":
			if sim.rng.randf() >= BINDING_CHANCE + caster.blessing_boosts.get("binding_chance", 0.0):
				return
			until = tick + BINDING_TICKS
			target.curses["bound"] = until
		"silencing":
			target.curses["silenced"] = true
		"manes":
			_call_the_manes(caster, events)
			until = tick + SHADE_LIFETIME
		"withering":
			until = tick + WITHERING_INTERVAL * WITHERING_PULSES
			var damage := 1 + floori(caster.level("ritus") / 25.0) + roundi(caster.blessing_boosts.get("withering_damage", 0.0))
			target.curses["withering"] = {"until": until, "next": tick + WITHERING_INTERVAL, "damage": damage, "source": caster.id}
	events.append({"type": "curse", "id": target.id, "curse": curse, "until": until, "source": caster.id, "tick": tick})


## Shades hunt their caster's target, drifting straight through walls, and
## fade when their time is up or their caster falls.
func process_summons(events: Array[Dictionary]) -> void:
	for id: int in sim.sorted_ids():
		var shade: Combatant = sim.get_combatant(id)
		if shade == null or shade.summoned_by == -1:
			continue
		var owner: Combatant = sim.get_combatant(shade.summoned_by)
		if owner == null or not owner.is_alive() or not shade.is_alive() or sim.tick >= shade.expires_at:
			sim.remove_combatant(id)
			events.append({"type": "summon_end", "id": id, "tick": sim.tick})
			continue
		var target: Combatant = sim.get_combatant(owner.target_id)
		shade.target_id = target.id if target and target.is_alive() else -1
		var goal: Vector3 = target.position if shade.target_id != -1 else owner.position
		var stop := shade.reach * 0.9 if shade.target_id != -1 else 2.0
		var offset := goal - shade.position
		offset.y = 0.0
		if offset.length() > stop:
			shade.position += offset.normalized() * minf(SHADE_STEP, offset.length() - stop)


## Withering pulses, and expired curses falling away.
func process(events: Array[Dictionary]) -> void:
	var tick: int = sim.tick
	for id: int in sim.sorted_ids():
		var victim: Combatant = sim.get_combatant(id)
		if victim == null or victim.curses.is_empty():
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
			var caster: Combatant = sim.get_combatant(wither["source"])
			if caster:
				victim.last_attacker_id = caster.id
			events.append({"type": "hit", "attacker": wither["source"], "target": victim.id, "damage": damage,
				"ranged": false, "kind": "withering", "tick": tick})
			if caster:
				sim.combat.award_combat_xp(caster, damage, events)
			if not victim.is_alive():
				sim.kill(victim, events)
				continue
		if tick >= wither["until"]:
			victim.curses.erase("withering")


## Summons (or refreshes) the caster's shade, which fights their target.
func _call_the_manes(caster: Combatant, events: Array[Dictionary]) -> void:
	var id := SHADE_ID_BASE + caster.id
	var shade: Combatant = sim.get_combatant(id)
	if shade == null:
		shade = sim.add_combatant(id)
		var level := maxi(1, floori(caster.level("ritus") * SHADE_LEVEL_SCALE))
		shade.levels = {"attack": level, "strength": level, "defence": 1}
		shade.max_hp = 20
		shade.hp = 20
		shade.attack_speed = 4
		shade.reach = 1.6
		shade.auto_retaliate = false
		shade.summoned_by = caster.id
		shade.position = caster.position + Vector3(0.8, 0, 0.8)
		events.append({"type": "summon", "id": id, "owner": caster.id, "position": shade.position, "tick": sim.tick})
	shade.expires_at = sim.tick + SHADE_LIFETIME
	shade.target_id = caster.target_id
