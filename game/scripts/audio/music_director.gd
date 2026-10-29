extends Node
## Plays the music music_composer.gd writes, on the Music bus: a style for
## the region the player is in (night in the open country, battle against a
## boss or on the munera's sand, the circus while racing), phrase after
## phrase with rests and the odd longer silence. A drone fades in under the
## styles that have one. Keeps playing while the game is paused.

const MusicComposer := preload("res://scripts/audio/music_composer.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")
const SAMPLE := "res://assets/audio/music/%s.wav"
const VOICES := ["lyre", "aulos", "drum_low", "drum_high"]
## Per-voice loudness in dB, to balance the samples against each other.
const VOICE_DB := {"lyre": -2.0, "aulos": -9.0, "drum_low": -6.0, "drum_high": -10.0}
const DRONE_DB := -16.0
## The drone sample's pitch, in semitones from middle C.
const DRONE_SEMITONE := -12
const DRONE_FADE := 2.0
const PLAYERS := 10
## Seconds between the old style stopping and the new one starting.
const CHANGE_GAP := 1.5
## Region (world map name) -> style.
const REGION_STYLES := {
	"Castra Ferrea": "fort", "Portus Salis": "coast", "Villa": "villa",
	"Barrow of the Lemures": "underground", "The deep gallery": "underground",
	"Beyond the Limes": "frontier", "Vipasca": "vipasca", "Seriphos": "seriphos",
	"Circus": "circus", "Rome": "rome",
}
## Styles night replaces: the open, settled places.
const NIGHT_STYLES := ["fort", "roads", "villa"]
## Chance of a longer silence after a phrase, and how long, in seconds.
const SILENCE_CHANCE := 0.15
const SILENCE_SECONDS := [6.0, 14.0]

@export var player: Node3D
@export var world_map: Node
@export var day_night: Node
@export var driver: Node

var style := ""
## Notes played, by voice (read by tests).
var played := {}
var composer := MusicComposer.new(int(Time.get_unix_time_from_system()))
var _time := 0.0
var _phrase_end := 0.0
## A longer silence after a phrase; a change of style ends it.
var _silence_end := 0.0
var _queue: Array = []
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _drone: AudioStreamPlayer
var _drone_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for voice in VOICES:
		_streams[voice] = load(SAMPLE % voice)
	for i in PLAYERS:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		add_child(p)
		_players.append(p)
	_drone = AudioStreamPlayer.new()
	_drone.bus = "Music"
	var drone_stream: AudioStreamWAV = load(SAMPLE % "drone")
	drone_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	drone_stream.loop_begin = 0
	drone_stream.loop_end = int(drone_stream.get_length() * drone_stream.mix_rate)
	_drone.stream = drone_stream
	_drone.volume_db = -80.0
	add_child(_drone)


func _process(delta: float) -> void:
	if player == null:
		return
	_time += delta
	var next := choose_style()
	if next != style:
		style = next
		_set_drone()
		# The old phrase stops; a fight cuts in at once, anything else after a
		# breath, and never after a silence.
		_queue.clear()
		_phrase_end = _time + (0.0 if next == "battle" else CHANGE_GAP)
		_silence_end = 0.0
	if _queue.is_empty() and _time >= _phrase_end and _time >= _silence_end:
		_compose()
	while not _queue.is_empty() and _queue[0]["at"] <= _time:
		_play(_queue.pop_front())


## The style for where the player is and what they're doing.
func choose_style() -> String:
	var combatant: RefCounted = player.get_node("SimEntity").combatant if player.has_node("SimEntity") else null
	if combatant:
		if not combatant.games.is_empty() or _fighting_boss(combatant):
			return "battle"
		if not combatant.race.is_empty():
			return "circus"
	var region: String = world_map.region_at(player.global_position) if world_map else ""
	var found: String = REGION_STYLES.get(region, "roads")
	if found in NIGHT_STYLES and day_night and day_night.is_night():
		return "night"
	return found


func _fighting_boss(combatant: RefCounted) -> bool:
	if driver == null or combatant.target_id < 0:
		return false
	var target: RefCounted = driver.sim.get_combatant(combatant.target_id)
	return target != null and target.is_alive() and target.monster_id != "" and ContentDB.monster(target.monster_id).has("boss")


func _compose() -> void:
	var phrase := composer.phrase(style)
	var beat := MusicComposer.beat_seconds(MusicComposer.STYLES[style])
	for note in phrase["notes"]:
		var queued: Dictionary = note.duplicate()
		queued["at"] = _time + note["beat"] * beat
		_queue.append(queued)
	_phrase_end = _time + phrase["beats"] * beat
	if style not in ["battle", "circus"] and composer.rng.randf() < SILENCE_CHANCE:
		_silence_end = _phrase_end + composer.rng.randf_range(SILENCE_SECONDS[0], SILENCE_SECONDS[1])


func _play(note: Dictionary) -> void:
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _streams[note["voice"]]
	p.pitch_scale = pow(2.0, note["semitone"] / 12.0)
	p.volume_db = linear_to_db(note["gain"]) + VOICE_DB[note["voice"]]
	p.play()
	played[note["voice"]] = played.get(note["voice"], 0) + 1


## Fades the drone out, retunes it to the new style's root, and fades it
## back in if the style has one.
func _set_drone() -> void:
	var data: Dictionary = MusicComposer.STYLES[style]
	if _drone_tween:
		_drone_tween.kill()
	if not _drone.playing and not data["drone"]:
		return
	_drone_tween = create_tween()
	if _drone.playing:
		_drone_tween.tween_property(_drone, "volume_db", -80.0, DRONE_FADE)
	if not data["drone"]:
		return
	_drone_tween.tween_callback(func():
		_drone.pitch_scale = pow(2.0, (data["root"] - DRONE_SEMITONE) / 12.0)
		if not _drone.playing:
			_drone.play())
	_drone_tween.tween_property(_drone, "volume_db", DRONE_DB, DRONE_FADE)
