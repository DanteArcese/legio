extends "res://tests/test_case.gd"
## Every sound the director can play points at a real file.

const SoundDirector := preload("res://scripts/audio/sound_director.gd")


func test_every_sound_file_exists() -> void:
	for sound in SoundDirector.SOUNDS:
		for variant in SoundDirector.SOUNDS[sound]:
			var path: String = SoundDirector.SYNTH % variant.trim_prefix("synth:") if variant.begins_with("synth:") else SoundDirector.KENNEY % variant
			check(ResourceLoader.exists(path), "%s: %s" % [sound, path])
