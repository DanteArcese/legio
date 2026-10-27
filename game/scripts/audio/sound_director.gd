extends Node
## Plays the game's sound. Sim events become positional one-shots (hits,
## curses, deaths, loot), skilling makes a sound on each swing, the player's
## steps follow their movement, every button clicks, and ambient loops
## crossfade by area and time of day.
##
## Volumes live on three buses (Master, Effects, Ambient) and are saved to
## user://settings.cfg alongside the graphics settings.

const SETTINGS_PATH := "user://settings.cfg"
const BUSES := ["Master", "Effects", "Ambient"]
const DEFAULT_VOLUMES := {"Master": 0.8, "Effects": 0.8, "Ambient": 0.6}
const KENNEY := "res://assets/kenney/audio/%s.ogg"
const SYNTH := "res://assets/audio/synth/%s.wav"
## Each sound name maps to variants; one is picked at random per play.
const SOUNDS := {
	"hit": ["impactPunch_medium_000", "impactPunch_medium_001", "impactPunch_medium_002", "impactPunch_medium_003", "impactPunch_medium_004"],
	"block": ["impactPlate_light_000", "impactPlate_light_001", "impactPlate_light_002"],
	"swing": ["synth:swish"],
	"bow": ["pluck_001"],
	"sling": ["synth:sling"],
	"cast": ["impactGlass_light_000", "impactGlass_light_001", "impactGlass_light_002"],
	"curse": ["bong_001"],
	"wither": ["impactSoft_medium_000", "impactSoft_medium_001"],
	"summon": ["impactBell_heavy_000"],
	"monster_death": ["impactSoft_heavy_000", "impactSoft_heavy_001"],
	"player_death": ["jingles_STEEL00"],
	"level_up": ["jingles_PIZZI00"],
	"contract_done": ["jingles_PIZZI05"],
	"quest_done": ["jingles_PIZZI10"],
	"coins": ["handleCoins"],
	"pickup": ["handleSmallLeather"],
	"eat": ["chop"],
	"mine": ["impactMining_000", "impactMining_001", "impactMining_002", "impactMining_003"],
	"smith": ["impactMetal_medium_000", "impactMetal_medium_001", "impactMetal_medium_002"],
	"smelt": ["metalPot1", "metalPot2"],
	"cook": ["metalPot1", "metalPot2"],
	"inscribe": ["scratch_001", "scratch_002", "scratch_003"],
	"chop": ["impactWood_light_000", "impactWood_light_001"],
	"fish": ["drop_001"],
	"fletch": ["scratch_001", "scratch_002"],
	"offer": ["impactWood_light_000", "impactWood_light_001"],
	"offered": ["bong_001"],
	"wash": ["cloth1", "cloth2"],
	"warning": ["error_004"],
	"step_grass": ["footstep_grass_000", "footstep_grass_001", "footstep_grass_002", "footstep_grass_003", "footstep_grass_004"],
	"step_stone": ["footstep_concrete_000", "footstep_concrete_001", "footstep_concrete_002", "footstep_concrete_003", "footstep_concrete_004"],
	"click": ["click_001", "click_002"],
}
## Per-sound loudness in dB, for sounds that come out of the packs too hot or too quiet.
const GAIN_DB := {"step_grass": -10.0, "step_stone": -12.0, "click": -6.0, "level_up": -4.0,
	"contract_done": -4.0, "player_death": -4.0, "wash": -6.0, "swing": -4.0, "mine": -3.0}
const AMBIENCE := {"day": "ambient_day", "night": "ambient_night", "town": "ambient_town", "barrow": "ambient_barrow",
	"coast": "ambient_coast", "frontier": "ambient_frontier", "vipasca": "ambient_vipasca"}
const HEARING_RANGE := 32.0
const STEP_DISTANCE := 1.7
const AMBIENT_FADE := 2.5
const VOICES := 16
## The fort's walls, where the ground is paved (matches the town watch's beat).
const TOWN := Rect2(-20, -20, 40, 40)
const UNDERGROUND_X := 100.0
const UNDERGROUND_END_X := 230.0
## Portus Salis lies far west of the fort.
const COAST_X := -150.0
## North of this is the frontier, beyond the Limes.
const FRONTIER_Z := -300.0
## South of this are the silver mines of Vipasca.
const VIPASCA_Z := 300.0

@export var driver: Node
@export var player: Node3D
@export var day_night: Node
## Playtests turn this off so they never touch real settings.
@export var persist := true

var volumes := DEFAULT_VOLUMES.duplicate()
var zone := ""
## Counts of what was played, by sound name (read by tests).
var played := {}
var _streams := {}
var _voices: Array[AudioStreamPlayer3D] = []
var _flat: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _ambient := {}
var _last_step_position := Vector3.INF
var _step_travel := 0.0
var _last_swing := -1
var _inventory_tick := -1
var _next_flat := 0


func _ready() -> void:
	_ensure_buses()
	_load_volumes()
	for i in VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.bus = "Effects"
		voice.max_distance = HEARING_RANGE
		voice.unit_size = 6.0
		add_child(voice)
		_voices.append(voice)
	for i in 4:
		var flat := AudioStreamPlayer.new()
		flat.bus = "Effects"
		add_child(flat)
		_flat.append(flat)
	for key in AMBIENCE:
		var loop := AudioStreamPlayer.new()
		loop.bus = "Ambient"
		loop.stream = _looping(load(SYNTH % AMBIENCE[key]))
		loop.volume_db = -80.0
		add_child(loop)
		_ambient[key] = loop
	if driver:
		driver.sim_event.connect(_on_sim_event)
		driver.ticked.connect(_on_tick)
	get_tree().node_added.connect(_on_node_added)
	for button in get_tree().root.find_children("*", "BaseButton", true, false):
		_on_node_added(button)


func _process(delta: float) -> void:
	if player == null:
		return
	_update_ambience()
	_update_steps(delta)


## Volume is linear, 0 to 1.
func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volume(bus)
	_save_volumes()


func volume(bus: String) -> float:
	return volumes.get(bus, 1.0)


## Plays a named sound at a world position, or flat (non-positional) when at is null.
func play(sound: String, at: Variant = null) -> void:
	var variants: Array = SOUNDS.get(sound, [])
	if variants.is_empty():
		return
	played[sound] = played.get(sound, 0) + 1
	var stream := _stream(variants[randi() % variants.size()])
	var gain: float = GAIN_DB.get(sound, 0.0)
	if at is Vector3:
		if player and player.global_position.distance_to(at) > HEARING_RANGE:
			return
		var voice := _voices[_next_voice]
		_next_voice = (_next_voice + 1) % _voices.size()
		voice.stream = stream
		voice.volume_db = gain
		voice.pitch_scale = randf_range(0.94, 1.06)
		voice.global_position = at
		voice.play()
	else:
		var flat := _flat[_next_flat]
		_next_flat = (_next_flat + 1) % _flat.size()
		flat.stream = stream
		flat.volume_db = gain
		flat.play()


func _on_sim_event(event: Dictionary) -> void:
	var sim: RefCounted = driver.sim
	var me: int = player.get_node("SimEntity").entity_id if player.has_node("SimEntity") else -1
	match event["type"]:
		"hit":
			var attacker: RefCounted = sim.get_combatant(event["attacker"])
			var target: RefCounted = sim.get_combatant(event["target"])
			var kind: String = event.get("kind", "melee")
			if attacker and kind != "withering":
				match kind:
					"ranged":
						play("sling" if _is_sling(attacker) else "bow", attacker.position)
					"ritus":
						play("cast", attacker.position)
					"spear":
						pass
					_:
						play("swing", attacker.position)
			if target:
				if kind == "withering":
					play("wither", target.position)
				elif event["damage"] > 0:
					play("hit", target.position)
				elif kind == "melee":
					play("block", target.position)
		"curse":
			var cursed: RefCounted = sim.get_combatant(event["id"])
			if cursed and event["curse"] != "manes":
				play("curse", cursed.position)
		"summon":
			play("summon", event["position"])
		"strike_warn":
			play("swing", event["position"])
		"enrage":
			var enraged: RefCounted = sim.get_combatant(event["id"])
			if enraged:
				play("summon", enraged.position)
		"death":
			var victim: RefCounted = sim.get_combatant(event["id"])
			if event["id"] == me:
				play("player_death")
			elif victim:
				play("monster_death", victim.position)
		"drop":
			if event["items"].any(func(entry): return entry["item"] == "coins"):
				play("coins", event["position"])
		"ground_remove", "ground_update":
			# A pile shrinking in the same tick the player's pack filled is a pickup.
			if _inventory_tick == event["tick"]:
				play("pickup", player.global_position)
				_inventory_tick = -1
		"level_up":
			if event["id"] == me:
				play("level_up")
		"slayer_complete":
			if event["id"] == me:
				play("contract_done")
		"quest_complete":
			if event["id"] == me:
				play("quest_done")
		"obstacle_started":
			if event["id"] == me:
				play("wash", player.global_position)
		"lap_complete":
			if event["id"] == me:
				play("coins", player.global_position)
		"patch_changed":
			if event["stage"] == 0:
				play("pickup", player.global_position)
		"trap_set", "trap_cleared":
			if event["id"] == me:
				play("offer", player.global_position)
		"stall_emptied":
			play("pickup", player.global_position)
		"pickpocketed":
			if event["id"] == me:
				play("coins", player.global_position)
		"caught":
			if event["id"] == me:
				play("warning")
		"ate":
			if event["id"] == me:
				play("eat")
		"offered":
			play("offered", player.global_position)
		"watch_warning", "watch_fine":
			if event["id"] == me:
				play("warning")
		"inventory_changed":
			if event["id"] == me:
				_inventory_tick = event["tick"]


## One sound per skilling attempt: the action's next_tick moves each time it swings.
func _on_tick(_tick: int) -> void:
	var entity: Node = player.get_node_or_null("SimEntity")
	if entity == null or entity.combatant == null:
		return
	var action: Dictionary = entity.combatant.skill_action
	var next: int = action.get("next_tick", -1)
	if action.is_empty() or next == _last_swing:
		_last_swing = next
		return
	if _last_swing != -1:
		var sound: String = action.get("kind", action.get("type", ""))
		play(sound, player.global_position)
	_last_swing = next


func _update_steps(_delta: float) -> void:
	var here := player.global_position
	if _last_step_position == Vector3.INF:
		_last_step_position = here
		return
	var moved := Vector2(here.x - _last_step_position.x, here.z - _last_step_position.z).length()
	_last_step_position = here
	# Teleports (doorways, respawns) aren't steps.
	if moved > 3.0:
		return
	_step_travel += moved
	if _step_travel >= STEP_DISTANCE:
		_step_travel = 0.0
		var paved := zone == "barrow" or TOWN.has_point(Vector2(here.x, here.z))
		play("step_stone" if paved else "step_grass", here)


func _update_ambience() -> void:
	var here := player.global_position
	var next := "day"
	if here.x > UNDERGROUND_X and here.x < UNDERGROUND_END_X:
		next = "barrow"
	elif here.x < COAST_X:
		next = "coast"
	elif here.z < FRONTIER_Z:
		next = "frontier"
	elif here.z > VIPASCA_Z:
		next = "vipasca"
	elif day_night and day_night.is_night():
		next = "night"
	elif TOWN.has_point(Vector2(here.x, here.z)):
		next = "town"
	if next == zone:
		return
	zone = next
	for key in _ambient:
		var loop: AudioStreamPlayer = _ambient[key]
		var tween := create_tween()
		if key == zone:
			if not loop.playing:
				loop.play()
			tween.tween_property(loop, "volume_db", 0.0, AMBIENT_FADE)
		else:
			tween.tween_property(loop, "volume_db", -80.0, AMBIENT_FADE)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_click):
		node.pressed.connect(_click)


func _click() -> void:
	play("click")


func _is_sling(combatant: RefCounted) -> bool:
	return combatant.equipment != null and "sling" in String(combatant.equipment.worn.get("weapon", ""))


func _stream(variant: String) -> AudioStream:
	if not _streams.has(variant):
		var path: String = SYNTH % variant.trim_prefix("synth:") if variant.begins_with("synth:") else KENNEY % variant
		_streams[variant] = load(path)
	return _streams[variant]


func _looping(stream: AudioStreamWAV) -> AudioStreamWAV:
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream


func _ensure_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")


func _apply_volume(bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	var value: float = volumes[bus]
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))


func _load_volumes() -> void:
	var config := ConfigFile.new()
	if persist and config.load(SETTINGS_PATH) == OK:
		for bus in BUSES:
			volumes[bus] = clampf(config.get_value("audio", bus.to_lower(), DEFAULT_VOLUMES[bus]), 0.0, 1.0)
	for bus in BUSES:
		_apply_volume(bus)


func _save_volumes() -> void:
	if not persist:
		return
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	for bus in BUSES:
		config.set_value("audio", bus.to_lower(), volumes[bus])
	config.save(SETTINGS_PATH)
