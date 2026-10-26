extends CanvasLayer
## A round minimap in the top-right corner. A small orthographic camera
## renders the world from above into a SubViewport, turned to match the
## main camera, and dots mark what's around: monsters (red), other people
## (yellow), loot (white), and places to use (blue).

const Quests := preload("res://scripts/sim/quests.gd")

const SIZE := 190
## Metres from the centre to the rim.
const RADIUS := 32.0
## Renders every few frames; the map doesn't need 60 fps.
const RENDER_EVERY := 3
const GROUPS := {
	"banks": Color(0.4, 0.7, 1.0), "stations": Color(0.4, 0.7, 1.0), "rocks": Color(0.4, 0.7, 1.0),
	"trees": Color(0.4, 0.7, 1.0), "fishing_spots": Color(0.4, 0.7, 1.0), "altars": Color(0.4, 0.7, 1.0),
	"transitions": Color(0.4, 0.7, 1.0), "hunt_spots": Color(0.4, 0.7, 1.0), "patches": Color(0.4, 0.7, 1.0), "trade_boards": Color(0.4, 0.7, 1.0), "shopkeepers": Color(1.0, 0.9, 0.3), "venatores": Color(1.0, 0.9, 0.3),
	"libitinarii": Color(1.0, 0.9, 0.3), "quest_npcs": Color(1.0, 0.9, 0.3), "loot_piles": Color(1.0, 1.0, 1.0),
}
const MONSTER := Color(0.95, 0.25, 0.2)
const CIRCLE_SHADER := """
shader_type canvas_item;
void fragment() {
	float d = distance(UV, vec2(0.5));
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= 1.0 - smoothstep(0.48, 0.5, d);
}
"""

@export var player: Node3D
@export var camera_rig: Node3D

var _viewport: SubViewport
var _camera: Camera3D
var _overlay: Control
var _frame := 0


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.world_3d = get_viewport().world_3d
	_viewport.positional_shadow_atlas_size = 0
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = RADIUS * 2.0
	_camera.near = 0.05
	_camera.far = 120.0
	# No fog or sky glare from up here.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.05, 0.06)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.9, 0.9, 0.9)
	environment.ambient_light_energy = 0.8
	_camera.environment = environment
	_viewport.add_child(_camera)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	root.position = Vector2(-SIZE - 20, 60)
	root.size = Vector2(SIZE, SIZE)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var map := TextureRect.new()
	map.texture = _viewport.get_texture()
	map.size = Vector2(SIZE, SIZE)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = CIRCLE_SHADER
	map.material = material
	root.add_child(map)
	_overlay = Control.new()
	_overlay.size = Vector2(SIZE, SIZE)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	root.add_child(_overlay)
	# Nothing is drawn without a display (headless playtests): skip the work.
	if DisplayServer.get_name() == "headless":
		set_process(false)


func _process(_delta: float) -> void:
	if player == null:
		return
	_frame += 1
	if _frame % RENDER_EVERY != 0:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var yaw := yaw()
	var here := player.global_position
	# Looking straight down, with the top of the map where the camera faces.
	_camera.global_transform = Transform3D(Basis.from_euler(Vector3(-PI / 2.0, yaw, 0.0)), here + Vector3(0, 40, 0))
	_overlay.queue_redraw()


func yaw() -> float:
	return camera_rig.global_rotation.y if camera_rig else 0.0


## Where a world position lands on the map, in map pixels (centre is the player).
func to_map(world: Vector3) -> Vector2:
	var offset := world - player.global_position
	var flat := Vector2(offset.x, offset.z).rotated(yaw())
	return Vector2(SIZE, SIZE) / 2.0 + flat * (SIZE / 2.0 / RADIUS)


## Everything with a dot, for tests: [{"position": Vector2, "color": Color}].
func dots() -> Array:
	var out := []
	for group in GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node3D:
				_add_dot(out, node.global_position, GROUPS[group])
	for entity in get_tree().get_nodes_in_group("sim_entities"):
		if entity.monster_id.is_empty() or entity.combatant == null or not entity.combatant.is_alive():
			continue
		_add_dot(out, entity.body().global_position, MONSTER)
	return out


func _add_dot(out: Array, world: Vector3, color: Color) -> void:
	var at := to_map(world)
	if at.distance_to(Vector2(SIZE, SIZE) / 2.0) <= SIZE / 2.0 - 9.0:
		out.append({"position": at, "color": color})


func _draw_overlay() -> void:
	var centre := Vector2(SIZE, SIZE) / 2.0
	_overlay.draw_arc(centre, SIZE / 2.0 - 1.0, 0.0, TAU, 64, Color(0.6, 0.48, 0.28), 3.0, true)
	for dot in dots():
		_overlay.draw_circle(dot["position"], 3.0, Color.BLACK)
		_overlay.draw_circle(dot["position"], 2.2, dot["color"])
	# Quest markers next to the NPCs that have something for you.
	var combatant: RefCounted = player.get_node("SimEntity").combatant if player.has_node("SimEntity") else null
	if combatant:
		for npc in get_tree().get_nodes_in_group("quest_npcs"):
			var marker := Quests.marker_for(combatant, npc.get_meta("npc_id"))
			var at := to_map(npc.global_position)
			if not marker.is_empty() and at.distance_to(centre) <= SIZE / 2.0 - 9.0:
				_overlay.draw_string(ThemeDB.fallback_font, at + Vector2(-4, -4), marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.85, 0.2))
	# The player: a white arrow pointing the way they face, relative to the camera.
	var facing := -(player.global_rotation.y - yaw())
	var tip := centre + Vector2(0, -7).rotated(facing)
	var left := centre + Vector2(-4.5, 5).rotated(facing)
	var right := centre + Vector2(4.5, 5).rotated(facing)
	_overlay.draw_colored_polygon(PackedVector2Array([tip, left, right]), Color.WHITE)
	# North marker on the rim.
	var north := centre + Vector2(0, -1).rotated(yaw()) * (SIZE / 2.0 - 10.0)
	_overlay.draw_string(ThemeDB.fallback_font, north + Vector2(-5, 6), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.85, 0.6))
