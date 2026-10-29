extends RefCounted
## Composes Legio's music a phrase at a time: short modal melodies on the
## lyre or aulos, over an optional drone and frame drums, in a style per
## region. Plain logic with its own random generator, so it's testable;
## music_director.gd plays what it writes.
##
## A phrase is {"notes": [{"beat", "voice", "semitone", "gain"}], "beats"},
## (a lyre's chord notes also have "bass": true)
## where semitones are relative to middle C (the samples' pitch) and
## "beats" is the phrase's whole length, including the rest after it.

## The Greek modes, as semitones above the root.
const MODES := {
	"dorian": [0, 2, 3, 5, 7, 9, 10],
	"phrygian": [0, 1, 3, 5, 7, 8, 10],
	"lydian": [0, 2, 4, 6, 7, 9, 11],
	"mixolydian": [0, 2, 4, 5, 7, 9, 10],
	"aeolian": [0, 2, 3, 5, 7, 8, 10],
	"ionian": [0, 2, 4, 5, 7, 9, 11],
}
## Rhythm cells in beats; a phrase strings a few together.
const CELLS := [[1.0, 1.0], [0.5, 0.5, 1.0], [1.5, 0.5], [1.0, 0.5, 0.5], [2.0], [0.5, 0.5, 0.5, 0.5]]
## Each style: its mode and root (semitones from middle C), tempo, lead
## voice, how many notes a phrase has, the rest between phrases, whether a
## drone sounds, how busy the drums are (0 for none), and the chance a
## phrase answers the last one instead of starting afresh.
const STYLES := {
	"fort": {"mode": "dorian", "root": -10, "bpm": 76, "voice": "lyre", "notes": [5, 8], "rest": [2, 5], "drone": false, "drums": 0.0, "echo": 0.4},
	"roads": {"mode": "mixolydian", "root": -7, "bpm": 70, "voice": "lyre", "notes": [4, 6], "rest": [4, 9], "drone": false, "drums": 0.0, "echo": 0.3},
	"night": {"mode": "aeolian", "root": -12, "bpm": 56, "voice": "lyre", "notes": [3, 5], "rest": [5, 10], "drone": false, "drums": 0.0, "echo": 0.3},
	"coast": {"mode": "mixolydian", "root": -5, "bpm": 72, "voice": "lyre", "notes": [5, 7], "rest": [3, 6], "drone": true, "drums": 0.0, "echo": 0.45},
	"villa": {"mode": "ionian", "root": -8, "bpm": 66, "voice": "lyre", "notes": [5, 8], "rest": [3, 7], "drone": false, "drums": 0.0, "echo": 0.5},
	"underground": {"mode": "phrygian", "root": -14, "bpm": 50, "voice": "lyre", "notes": [2, 4], "rest": [6, 12], "drone": true, "drums": 0.0, "echo": 0.2},
	"frontier": {"mode": "aeolian", "root": -12, "bpm": 62, "voice": "aulos", "notes": [3, 6], "rest": [4, 8], "drone": true, "drums": 0.25, "echo": 0.3},
	"vipasca": {"mode": "phrygian", "root": -9, "bpm": 68, "voice": "aulos", "notes": [4, 7], "rest": [3, 6], "drone": true, "drums": 0.2, "echo": 0.35},
	"seriphos": {"mode": "lydian", "root": -7, "bpm": 74, "voice": "lyre", "notes": [5, 8], "rest": [2, 5], "drone": false, "drums": 0.0, "echo": 0.45},
	"rome": {"mode": "ionian", "root": -7, "bpm": 80, "voice": "lyre", "notes": [6, 9], "rest": [2, 4], "drone": false, "drums": 0.15, "echo": 0.45},
	"circus": {"mode": "mixolydian", "root": -10, "bpm": 96, "voice": "aulos", "notes": [6, 9], "rest": [1, 3], "drone": false, "drums": 0.7, "echo": 0.4},
	"battle": {"mode": "phrygian", "root": -12, "bpm": 104, "voice": "aulos", "notes": [5, 8], "rest": [1, 2], "drone": true, "drums": 0.9, "echo": 0.5},
}
## Scale degrees a melody may use, around the root.
const LOWEST := -2
const HIGHEST := 9
## Below this (semitones from middle C) a repitched sample gets muddy.
const LOWEST_SEMITONE := -19
const STEPS := [-2, -1, -1, -1, 1, 1, 1, 2, 3, -3, 0]

var rng := RandomNumberGenerator.new()
var _last := {}


func _init(seed_value: int = 0) -> void:
	rng.seed = seed_value


## Semitones from middle C for a scale degree in a style.
static func pitch(style: Dictionary, degree: int) -> int:
	var mode: Array = MODES[style["mode"]]
	var octave := floori(degree / 7.0)
	return style["root"] + mode[degree - octave * 7] + 12 * octave


## Seconds per beat in a style.
static func beat_seconds(style: Dictionary) -> float:
	return 60.0 / style["bpm"]


## The next phrase in a style.
func phrase(style_name: String) -> Dictionary:
	var style: Dictionary = STYLES[style_name]
	var degrees: Array[int] = []
	var lengths: Array[float] = []
	if _last.get("style") == style_name and rng.randf() < style["echo"]:
		# Answer the last phrase: its rhythm, its shape a step away.
		var shift := 1 if rng.randf() < 0.5 else -1
		for d in _last["degrees"]:
			degrees.append(clampi(d + shift, LOWEST, HIGHEST))
		lengths.assign(_last["lengths"])
	else:
		var count := rng.randi_range(style["notes"][0], style["notes"][1])
		var degree: int = [0, 2, 4][rng.randi() % 3]
		while degrees.size() < count:
			var cell: Array = CELLS[rng.randi() % CELLS.size()]
			for length in cell:
				if degrees.size() >= count:
					break
				degrees.append(degree)
				lengths.append(length)
				degree = clampi(degree + STEPS[rng.randi() % STEPS.size()], LOWEST, HIGHEST)
	# End at rest: on the root or the fifth, held.
	var last := degrees.size() - 1
	degrees[last] = _settle(degrees[last])
	lengths[last] = maxf(lengths[last], 2.0)
	_last = {"style": style_name, "degrees": degrees.duplicate(), "lengths": lengths.duplicate()}

	var notes: Array = []
	var beat := 0.0
	for i in degrees.size():
		var gain := 1.0 if i == 0 else 0.8 + 0.15 * rng.randf()
		notes.append({"beat": beat, "voice": style["voice"], "semitone": pitch(style, degrees[i]), "gain": gain})
		# Open and close over the tonic in the octave below, plucked with
		# the melody like a strummed chord.
		if style["voice"] == "lyre" and (i == 0 or i == last):
			var melody_note := pitch(style, degrees[i])
			var low: int = style["root"] + 12 * floori((melody_note - style["root"] - 1) / 12.0)
			notes.append({"beat": beat, "voice": "lyre", "semitone": low + 12 if low < LOWEST_SEMITONE else low, "gain": 0.45, "bass": true})
		beat += lengths[i]
	var rest := float(rng.randi_range(style["rest"][0], style["rest"][1]))
	var beats := ceilf(beat) + rest
	if style["drums"] > 0.0:
		for b in int(beats):
			if b % 4 == 0:
				notes.append({"beat": float(b), "voice": "drum_low", "semitone": 0, "gain": 0.9})
			elif rng.randf() < style["drums"]:
				notes.append({"beat": b + (0.5 if rng.randf() < 0.4 else 0.0), "voice": "drum_high", "semitone": 0, "gain": 0.6})
	notes.sort_custom(func(a, b): return a["beat"] < b["beat"])
	return {"notes": notes, "beats": beats}


## The nearest root (0, 7) or fifth (4, -3 is the fifth below) to a degree.
func _settle(degree: int) -> int:
	var best := 0
	for target in [-3, 0, 4, 7]:
		if absi(target - degree) < absi(best - degree):
			best = target
	return best
