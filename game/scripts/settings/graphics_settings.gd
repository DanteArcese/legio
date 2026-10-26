extends Node
## Look and graphics presets. The base look (tonemapping, colour grading,
## fog) is the same everywhere; presets trade ambient occlusion, glow,
## shadow quality, and anti-aliasing for speed. Choices are saved to
## user://settings.cfg.

const PRESETS := ["low", "medium", "high"]
const DEFAULT_PRESET := "medium"
const SETTINGS_PATH := "user://settings.cfg"

signal changed

@export var environment: WorldEnvironment
@export var sun: DirectionalLight3D
@export var occlusion_fader: Node
## Playtests turn this off so they never touch real settings.
@export var persist := true

var preset := DEFAULT_PRESET


func _ready() -> void:
	_apply_base_look()
	var config := ConfigFile.new()
	if persist and config.load(SETTINGS_PATH) == OK:
		preset = config.get_value("graphics", "preset", DEFAULT_PRESET)
		if occlusion_fader:
			occlusion_fader.set_hide_roofs(config.get_value("view", "hide_roofs", false))
	apply_preset(preset if preset in PRESETS else DEFAULT_PRESET)


func cycle_preset() -> void:
	apply_preset(PRESETS[(PRESETS.find(preset) + 1) % PRESETS.size()])
	save()


func set_hide_roofs(value: bool) -> void:
	if occlusion_fader:
		occlusion_fader.set_hide_roofs(value)
	save()


func hide_roofs() -> bool:
	return occlusion_fader != null and occlusion_fader.hide_roofs


func apply_preset(name: String) -> void:
	preset = name
	var env := environment.environment
	var viewport := get_viewport()
	match name:
		"low":
			env.ssao_enabled = false
			env.glow_enabled = false
			sun.shadow_enabled = true
			RenderingServer.directional_shadow_atlas_set_size(1024, false)
			sun.directional_shadow_max_distance = 40.0
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		"medium":
			env.ssao_enabled = true
			env.ssao_radius = 1.2
			env.ssao_intensity = 1.6
			env.glow_enabled = false
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			sun.directional_shadow_max_distance = 70.0
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		"high":
			env.ssao_enabled = true
			env.ssao_radius = 1.5
			env.ssao_intensity = 2.0
			env.glow_enabled = true
			env.glow_intensity = 0.35
			env.glow_bloom = 0.04
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			sun.directional_shadow_max_distance = 110.0
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	changed.emit()


func save() -> void:
	if not persist:
		return
	# Load first: other settings (audio) share the file.
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("graphics", "preset", preset)
	config.set_value("view", "hide_roofs", hide_roofs())
	config.save(SETTINGS_PATH)


## The shared art direction: warm sun, cool shadows, a little extra colour,
## like a clear OSRS afternoon.
func _apply_base_look() -> void:
	var env := environment.environment
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 1.25
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.1
	sun.shadow_opacity = 0.7
	sun.shadow_blur = 2.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
