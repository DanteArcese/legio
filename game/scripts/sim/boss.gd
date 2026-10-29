extends RefCounted
## Boss mechanics, driven by a monster's "boss" block in monsters.json:
## every few attacks the boss throws at where its target stands instead of
## striking, marking the spot; the throw lands a few ticks later on anyone
## still inside. Below a fraction of its health it enrages and attacks faster.
##
## Bosses with "stances" fight in turns: a few attacks of one kind (melee,
## ranged or Ritus, at its own reach), then the next stance, announced by its
## tell right after the last attack of the old one, so the player has an
## attack's time to switch protection.

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
## What a boss shouts as it throws, by the boss block's throw_kind.
const THROW_WARNINGS := {"spear": "%s hurls a spear at you. Move!", "venom": "%s spits venom at you. Move!",
	"boulder": "%s heaves a boulder at you. Move!"}
## Throws in the air: {"id", "boss", "kind", "position", "lands_at", "radius", "damage"}.
var strikes: Array[Dictionary] = []
var _next_strike_id := 1
## boss id -> attacks made since it last (re)spawned.
var _attacks := {}
var _enraged := {}
var _regen_warned := {}
## boss id -> {"index", "left", "reach"}: its stance and attacks left in it.
var _stances := {}


func _init(p_sim: RefCounted) -> void:
	sim = p_sim


static func data(monster_id: String) -> Dictionary:
	return ContentDB.monster(monster_id).get("boss", {}) if not monster_id.is_empty() else {}


## Called when a boss is about to attack. Returns true if this attack was a
## throw (marked now, landing later) rather than a normal strike.
func try_throw(boss: Combatant, target: Combatant, events: Array[Dictionary]) -> bool:
	var spec := data(boss.monster_id)
	if spec.is_empty():
		return false
	if spec.has("stances") and not _stances.has(boss.id):
		_stances[boss.id] = {"index": 0, "left": 0, "reach": boss.reach}
		_enter_stance(boss, target, events)
	_attacks[boss.id] = _attacks.get(boss.id, 0) + 1
	if _attacks[boss.id] % int(spec["throw_every"]) != 0:
		return false
	var tick: int = sim.tick
	var kind: String = spec.get("throw_kind", "spear")
	var strike := {"id": _next_strike_id, "boss": boss.id, "kind": kind, "position": target.position, "lands_at": tick + int(spec["throw_delay"]),
		"radius": float(spec["throw_radius"]), "damage": spec["throw_damage"]}
	_next_strike_id += 1
	strikes.append(strike)
	boss.next_attack_tick = tick + boss.current_attack_speed(tick)
	events.append({"type": "strike_warn", "id": boss.id, "strike": strike["id"], "kind": kind, "position": strike["position"],
		"radius": strike["radius"], "lands_at": strike["lands_at"], "tick": tick})
	sim.message(target, THROW_WARNINGS[kind] % ContentDB.monster(boss.monster_id)["name"], events)
	return true


## After a boss's (non-throw) attack: counts down its stance, and moves it to
## the next once spent, telling its foe.
func after_attack(boss: Combatant, target: Combatant, events: Array[Dictionary]) -> void:
	if not _stances.has(boss.id):
		return
	var state: Dictionary = _stances[boss.id]
	state["left"] -= 1
	if state["left"] <= 0:
		state["index"] = (state["index"] + 1) % data(boss.monster_id)["stances"].size()
		_enter_stance(boss, target, events)


## The stance a boss is in now, or {} for none.
func stance(boss: Combatant) -> Dictionary:
	if not _stances.has(boss.id):
		return {}
	return data(boss.monster_id)["stances"][_stances[boss.id]["index"]]


func _enter_stance(boss: Combatant, target: Combatant, events: Array[Dictionary]) -> void:
	var state: Dictionary = _stances[boss.id]
	var spec: Dictionary = data(boss.monster_id)["stances"][state["index"]]
	state["left"] = int(spec["attacks"])
	boss.attack_kind = spec["kind"]
	boss.reach = float(spec.get("reach", state["reach"]))
	events.append({"type": "boss_stance", "id": boss.id, "kind": spec["kind"], "tick": sim.tick})
	if target and target.is_player():
		sim.message(target, spec["tell"].replace("{name}", ContentDB.monster(boss.monster_id)["name"]), events)


## Back to the first stance and the boss's own reach and kind of blow.
func _reset_stance(boss: Combatant) -> void:
	if not _stances.has(boss.id):
		return
	boss.reach = _stances[boss.id]["reach"]
	boss.attack_kind = ContentDB.monster(boss.monster_id).get("attack_kind", "melee")
	_stances.erase(boss.id)


## Lands throws that are due, and enrages bosses that are low on health.
func process(events: Array[Dictionary]) -> void:
	var tick: int = sim.tick
	var due := strikes.filter(func(strike): return strike["lands_at"] <= tick)
	strikes = strikes.filter(func(strike): return strike["lands_at"] > tick)
	for strike in due:
		_land(strike, events)
	_regenerate(events)
	for combatant in sim.combatants():
		var spec := data(combatant.monster_id)
		if spec.is_empty():
			continue
		# Out of the fight and healed (or respawned): start again from the top.
		if combatant.target_id == -1 and combatant.hp == combatant.max_hp:
			_reset_stance(combatant)
		var base: int = ContentDB.monster(combatant.monster_id)["attack_speed"]
		var low: bool = combatant.is_alive() and combatant.hp < combatant.max_hp * float(spec["enrage_below"])
		if low and not _enraged.get(combatant.id, false):
			_enraged[combatant.id] = true
			combatant.attack_speed = int(spec["enrage_speed"])
			events.append({"type": "enrage", "id": combatant.id, "tick": tick})
			var foe: Combatant = sim.get_combatant(combatant.target_id)
			if foe and foe.is_player():
				sim.message(foe, "%s roars, and comes at you faster!" % ContentDB.monster(combatant.monster_id)["name"], events)
		elif not low and _enraged.get(combatant.id, false) and combatant.hp == combatant.max_hp:
			# Back at full health: respawned, or healed after a retreat.
			_enraged.erase(combatant.id)
			_attacks.erase(combatant.id)
			combatant.attack_speed = base


## Monsters with a "regenerate" block (the hydra) heal every tick unless
## seared by fire. Their foe is told the first time the wounds close.
func _regenerate(events: Array[Dictionary]) -> void:
	for combatant in sim.combatants():
		if combatant.monster_id.is_empty() or not combatant.is_alive() or combatant.hp >= combatant.max_hp:
			continue
		var regen: Dictionary = ContentDB.monster(combatant.monster_id).get("regenerate", {})
		if regen.is_empty() or sim.tick < combatant.seared_until:
			continue
		combatant.hp = mini(combatant.hp + int(regen["amount"]), combatant.max_hp)
		var foe: Combatant = sim.get_combatant(combatant.target_id)
		if foe and foe.is_player() and not _regen_warned.get(combatant.id, false):
			_regen_warned[combatant.id] = true
			sim.message(foe, "The %s's wounds close as fast as you make them! Sear them with fire." % ContentDB.monster(combatant.monster_id)["name"].to_lower(), events)
		if combatant.hp == combatant.max_hp:
			_regen_warned.erase(combatant.id)


## A boss that dies takes its throws in the air with it.
func on_death(boss: Combatant, events: Array[Dictionary]) -> void:
	for strike in strikes:
		if strike["boss"] == boss.id:
			events.append({"type": "strike_land", "id": boss.id, "strike": strike["id"], "position": strike["position"], "tick": sim.tick})
	strikes = strikes.filter(func(strike): return strike["boss"] != boss.id)


func _land(strike: Dictionary, events: Array[Dictionary]) -> void:
	var boss: Combatant = sim.get_combatant(strike["boss"])
	events.append({"type": "strike_land", "id": strike["boss"], "strike": strike["id"], "position": strike["position"], "tick": sim.tick})
	if boss == null or not boss.is_alive():
		return
	for combatant in sim.combatants():
		if not combatant.is_player() or not combatant.is_alive():
			continue
		if sim.flat_distance(combatant.position, strike["position"]) > strike["radius"]:
			continue
		var damage := mini(sim.rng.randi_range(strike["damage"][0], strike["damage"][1]), combatant.hp)
		combatant.hp -= damage
		combatant.last_attacker_id = boss.id
		events.append({"type": "hit", "attacker": boss.id, "target": combatant.id, "damage": damage,
			"ranged": false, "kind": strike["kind"], "tick": sim.tick})
		if not combatant.is_alive():
			sim.kill(combatant, events)
