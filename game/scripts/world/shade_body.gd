extends Node3D
## The visible shade of the Manes: a translucent, glowing skeleton that
## glides after its sim position (shades drift through walls, so no physics)
## and fades in and out.

const KaykitCharacter := preload("res://scripts/world/kaykit_character.gd")
const FOLLOW_RATE := 6.0
const FADE_TIME := 0.4

var shade_id := 0
var driver: Node
var model: Node3D


static func spawn(parent: Node, p_driver: Node, id: int, at: Vector3) -> Node3D:
	var body := new()
	body.shade_id = id
	body.driver = p_driver
	parent.add_child(body)
	body.global_position = at
	return body


func _ready() -> void:
	model = KaykitCharacter.create({"scene": "skeletons/Skeleton_Minion"})
	add_child(model)
	_ghostly(model)
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, FADE_TIME)


func fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, FADE_TIME)
	tween.tween_callback(queue_free)


func attack() -> void:
	if model:
		model.attack("slash")


func _process(delta: float) -> void:
	var shade: RefCounted = driver.sim.get_combatant(shade_id)
	if shade == null:
		return
	var goal: Vector3 = shade.position
	var step := (goal - global_position) * minf(FOLLOW_RATE * delta, 1.0)
	global_position += step
	var flat := Vector2(step.x, step.z)
	if flat.length() > 0.001:
		rotation.y = atan2(-step.x, -step.z)
	model.animate(delta, flat.length() / maxf(delta, 0.001))


func _ghostly(node: Node) -> void:
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var base := mesh.mesh.surface_get_material(i) as StandardMaterial3D
			if base == null:
				continue
			var ghost := base.duplicate() as StandardMaterial3D
			ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ghost.albedo_color = Color(0.7, 0.85, 1.0, 0.5)
			ghost.emission_enabled = true
			ghost.emission = Color(0.35, 0.55, 0.9)
			ghost.emission_energy_multiplier = 0.8
			mesh.set_surface_override_material(i, ghost)
