extends Node
## Day and night: the sun arcs across the sky over a cycle of real minutes,
## and sun, sky, ambient, and fog colours follow keyframes through dawn,
## day, dusk, and night. A dim moon lights the night, and lamps (group
## "lamps") glow after dark. Underground, the dungeon's own lighting wins.

## Keyframes by hour: sun colour and energy, sky top and horizon, ambient energy, moon energy.
const KEYS := [
	[0.0, Color(0.4, 0.45, 0.7), 0.0, Color(0.03, 0.04, 0.1), Color(0.08, 0.1, 0.18), 0.45, 0.32],
	[5.0, Color(0.6, 0.5, 0.6), 0.0, Color(0.06, 0.07, 0.16), Color(0.2, 0.16, 0.22), 0.5, 0.25],
	[6.5, Color(1.0, 0.62, 0.38), 0.6, Color(0.3, 0.4, 0.62), Color(0.95, 0.62, 0.42), 0.8, 0.0],
	[9.0, Color(1.0, 0.95, 0.85), 1.1, Color(0.38, 0.55, 0.82), Color(0.68, 0.76, 0.86), 1.25, 0.0],
	[16.0, Color(1.0, 0.93, 0.8), 1.1, Color(0.38, 0.55, 0.82), Color(0.7, 0.76, 0.84), 1.25, 0.0],
	[18.5, Color(1.0, 0.68, 0.42), 0.8, Color(0.36, 0.46, 0.7), Color(0.95, 0.66, 0.48), 1.0, 0.0],
	[20.5, Color(0.5, 0.45, 0.7), 0.0, Color(0.06, 0.06, 0.15), Color(0.22, 0.15, 0.25), 0.5, 0.22],
	[24.0, Color(0.4, 0.45, 0.7), 0.0, Color(0.03, 0.04, 0.1), Color(0.08, 0.1, 0.18), 0.45, 0.32],
]
const SUNRISE := 6.0
const SUNSET := 20.0
const MAX_ELEVATION := 68.0
const SUN_YAW := -35.0
const LAMP_ENERGY := 1.6

@export var environment: WorldEnvironment
@export var sun: DirectionalLight3D
@export var moon: DirectionalLight3D
@export var area_lighting: Node
## Real minutes for a full day.
@export var cycle_minutes := 20.0
@export_range(0.0, 24.0) var hour := 10.0
@export var running := true


func _process(delta: float) -> void:
	if running:
		hour = fmod(hour + delta * 24.0 / (cycle_minutes * 60.0), 24.0)
	if area_lighting and area_lighting.underground:
		_set_lamps(0.0)
		if moon:
			moon.light_energy = 0.0
		return
	apply()


func is_night() -> bool:
	return hour < SUNRISE or hour > SUNSET


## Applies the lighting for the current hour.
func apply() -> void:
	var key := _sample()
	var day_fraction := clampf((hour - SUNRISE) / (SUNSET - SUNRISE), 0.0, 1.0)
	var elevation := sin(day_fraction * PI) * MAX_ELEVATION
	sun.rotation_degrees = Vector3(-maxf(elevation, 4.0), SUN_YAW + day_fraction * 120.0, 0.0)
	sun.light_color = key["sun_color"]
	sun.light_energy = key["sun_energy"]
	sun.visible = key["sun_energy"] > 0.01
	if moon:
		moon.light_energy = key["moon"]
		moon.visible = key["moon"] > 0.01
	var env := environment.environment
	env.ambient_light_energy = key["ambient"]
	env.fog_light_color = key["horizon"].lerp(Color(0.72, 0.78, 0.85), 0.3)
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	if sky:
		sky.sky_top_color = key["top"]
		sky.sky_horizon_color = key["horizon"]
		sky.ground_horizon_color = key["horizon"].darkened(0.2)
	var night := 1.0 - smoothstep(0.0, 0.3, key["sun_energy"])
	_set_lamps(night * LAMP_ENERGY)


func _set_lamps(energy: float) -> void:
	for lamp in get_tree().get_nodes_in_group("lamps"):
		if lamp is Light3D:
			lamp.light_energy = energy
			lamp.visible = energy > 0.01


func _sample() -> Dictionary:
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if hour >= a[0] and hour <= b[0]:
			var t: float = (hour - a[0]) / (b[0] - a[0])
			return {
				"sun_color": (a[1] as Color).lerp(b[1], t), "sun_energy": lerpf(a[2], b[2], t),
				"top": (a[3] as Color).lerp(b[3], t), "horizon": (a[4] as Color).lerp(b[4], t),
				"ambient": lerpf(a[5], b[5], t), "moon": lerpf(a[6], b[6], t),
			}
	return {}
