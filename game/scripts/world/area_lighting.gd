extends Node
## Switches the lighting when the player is underground (the dungeon area
## lies east of x = UNDERGROUND_X), and back when they return.

const UNDERGROUND_X := 100.0

@export var environment: WorldEnvironment
@export var sun: DirectionalLight3D
@export var player: Node3D

var underground := false
var _surface := {}


func _ready() -> void:
	var env := environment.environment
	_surface = {
		"background_mode": env.background_mode, "ambient_energy": env.ambient_light_energy,
		"ambient_source": env.ambient_light_source, "ambient_color": env.ambient_light_color,
		"fog_color": env.fog_light_color, "fog_begin": env.fog_depth_begin, "fog_end": env.fog_depth_end,
		"sun": sun.light_energy,
	}


func _process(_delta: float) -> void:
	var below := player.global_position.x > UNDERGROUND_X
	if below != underground:
		underground = below
		_apply()


func _apply() -> void:
	var env := environment.environment
	if underground:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color.BLACK
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.35, 0.33, 0.4)
		env.ambient_light_energy = 0.35
		env.fog_light_color = Color.BLACK
		env.fog_depth_begin = 12.0
		env.fog_depth_end = 45.0
		sun.light_energy = 0.0
	else:
		env.background_mode = _surface["background_mode"]
		env.ambient_light_source = _surface["ambient_source"]
		env.ambient_light_color = _surface["ambient_color"]
		env.ambient_light_energy = _surface["ambient_energy"]
		env.fog_light_color = _surface["fog_color"]
		env.fog_depth_begin = _surface["fog_begin"]
		env.fog_depth_end = _surface["fog_end"]
		sun.light_energy = _surface["sun"]
