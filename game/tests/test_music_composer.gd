extends "res://tests/test_case.gd"
## The music composer: phrases stay in their mode and range, end at rest,
## and are the same for the same seed.

const MusicComposer := preload("res://scripts/audio/music_composer.gd")


func test_degrees_map_onto_the_mode() -> void:
	var style := {"mode": "dorian", "root": -10}
	check_eq(MusicComposer.pitch(style, 0), -10, "the root")
	check_eq(MusicComposer.pitch(style, 2), -7, "a minor third up")
	check_eq(MusicComposer.pitch(style, 7), 2, "an octave up")
	check_eq(MusicComposer.pitch(style, -3), -15, "the fifth below")


func test_every_style_writes_playable_phrases() -> void:
	var composer := MusicComposer.new(7)
	for name in MusicComposer.STYLES:
		var style: Dictionary = MusicComposer.STYLES[name]
		var allowed := {}
		for octave in [-2, -1, 0, 1, 2]:
			for step in MusicComposer.MODES[style["mode"]]:
				allowed[style["root"] + step + 12 * octave] = true
		for i in 20:
			var phrase := composer.phrase(name)
			var melody: Array = phrase["notes"].filter(func(n): return n["voice"] == style["voice"] and not n.get("bass", false))
			check(not melody.is_empty(), "%s has a melody" % name)
			for note in phrase["notes"]:
				check(note["beat"] < phrase["beats"], "%s notes fall inside the phrase" % name)
				if note["voice"] in ["lyre", "aulos"]:
					check(allowed.has(note["semitone"]), "%s stays in %s (%d)" % [name, style["mode"], note["semitone"]])
					check(note["semitone"] >= MusicComposer.LOWEST_SEMITONE and note["semitone"] <= 24, "%s in range (%d)" % [name, note["semitone"]])
			var last: int = melody.back()["semitone"]
			var root: int = style["root"]
			check(posmod(last - root, 12) in [0, 7], "%s ends on the root or fifth" % name)
			check_eq(style["drums"] > 0.0, phrase["notes"].any(func(n): return n["voice"].begins_with("drum")), "%s drums only if it has them" % name)


func test_same_seed_same_music() -> void:
	var a := MusicComposer.new(42)
	var b := MusicComposer.new(42)
	for i in 5:
		check_eq(a.phrase("fort"), b.phrase("fort"), "phrase %d" % i)
