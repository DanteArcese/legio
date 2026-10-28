extends Node
## Look and graphics presets. The base look (tonemapping, colour grading,
## fog) is the same everywhere; presets trade ambient occlusion, glow,
## shadow quality, and anti-aliasing for speed. Fullscreen (F11 or the pause
## menu) is kept here too. Choices are saved to user://settings.cfg.

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
var fullscreen := false


func _ready() -> void:
	_apply_base_look()
	var config := ConfigFile.new()
	if persist and config.load(SETTINGS_PATH) == OK:
		preset = config.get_value("graphics", "preset", DEFAULT_PRESET)
		if occlusion_fader:
			occlusion_fader.set_hide_roofs(config.get_value("view", "hide_roofs", false))
		fullscreen = config.get_value("view", "fullscreen", false)
	apply_preset(preset if preset in PRESETS else DEFAULT_PRESET)
	_apply_fullscreen()


## F11 is a plain key, like F3: controllers use the pause menu's button.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		set_fullscreen(not fullscreen)
		get_viewport().set_input_as_handled()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_fullscreen()
	save()


func _apply_fullscreen() -> void:
	# Headless runs (tests, CI) have no window to resize.
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


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
	config.set_value("view", "fullscreen", fullscreen)
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
