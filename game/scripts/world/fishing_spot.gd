extends StaticBody3D
## A fishing spot in the pond: rings of ripples on the water. Its click
## shape stands a little above the pond's invisible edge blocker, so
## clicking the ripples picks the spot rather than the spring.

const ContentDB := preload("res://scripts/content/content_db.gd")
const RING_PERIOD := 1.8
const RINGS := 3
const VERBS := {"net": "Net", "rod": "Cast", "harpoon": "Harpoon"}

@export var spot_type := "net_spot"

var spot_id := 0
var _rings: Array[MeshInstance3D] = []
var _time := 0.0


func _init() -> void:
	collision_layer = 8
	collision_mask = 0
	add_to_group("fishing_spots")


func _ready() -> void:
	var shape := CollisionShape3D.new()
	shape.shape = CylinderShape3D.new()
	shape.shape.radius = 0.9
	shape.shape.height = 4.6
	shape.position.y = 0.4
	add_child(shape)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.93, 1.0, 0.7)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in RINGS:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.42
		torus.outer_radius = 0.5
		torus.rings = 24
		torus.ring_segments = 4
		ring.mesh = torus
		ring.material_override = material.duplicate()
		ring.scale = Vector3(1, 0.15, 1)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_rings.append(ring)
	var label := Label3D.new()
	label.text = display_name()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.outline_size = 8
	label.position.y = 1.0
	label.visibility_range_end = 30.0
	add_child(label)


func _process(delta: float) -> void:
	_time += delta
	for i in _rings.size():
		var t := fmod(_time / RING_PERIOD + float(i) / RINGS, 1.0)
		var ring := _rings[i]
		var size := lerpf(0.3, 1.6, t)
		ring.scale = Vector3(size, 0.15, size)
		(ring.material_override as StandardMaterial3D).albedo_color.a = 0.7 * (1.0 - t)


func display_name() -> String:
	return "%s (%s)" % [ContentDB.fishing_spot(spot_type).get("name", "Fishing spot"), _tool_name()]


func examine_text() -> String:
	return ContentDB.fishing_spot(spot_type).get("examine", "")


func verb() -> String:
	return VERBS.get(ContentDB.fishing_spot(spot_type).get("tool"), "Fish")


func _tool_name() -> String:
	return ContentDB.fishing_spot(spot_type).get("tool", "net")
