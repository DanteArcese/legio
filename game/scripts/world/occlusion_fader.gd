extends Node
## Keeps the player visible: structures (layer 16: walls, buildings, trees)
## between the camera and the player fade out, along with their roofs, and
## fade back in once out of the way. "Hide roofs" (H / R3) hides every roof.

const STRUCTURE_LAYER := 16
const FADED := 0.85
const FADE_SPEED := 6.0
## Rays to the player's feet, middle, and head, so partial cover also fades.
const AIM_HEIGHTS := [0.2, 1.0, 1.8]
const MAX_HITS_PER_RAY := 4

@export var camera_rig: Node3D
@export var player: Node3D
@export var hide_roofs := false

## MeshInstance3D -> current transparency
var _fading := {}


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_roofs"):
		set_hide_roofs(not hide_roofs)


func set_hide_roofs(value: bool) -> void:
	hide_roofs = value
	for roof in _all_roofs():
		roof.visible = not hide_roofs


func occluders() -> Array[Node3D]:
	var camera := get_viewport().get_camera_3d()
	var found: Array[Node3D] = []
	if camera == null or player == null:
		return found
	var space := player.get_world_3d().direct_space_state
	for height in AIM_HEIGHTS:
		var exclude: Array[RID] = []
		var target: Vector3 = player.global_position + Vector3(0, height - 1.0, 0)
		for i in MAX_HITS_PER_RAY:
			var query := PhysicsRayQueryParameters3D.create(camera.global_position, target, STRUCTURE_LAYER, exclude)
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				break
			var body: Node3D = hit["collider"]
			if not found.has(body):
				found.append(body)
			exclude.append(hit["rid"])
	return found


func _process(delta: float) -> void:
	var wanted := {}
	for body in occluders():
		for mesh in _meshes_of(body):
			wanted[mesh] = true
	for mesh in wanted:
		if not _fading.has(mesh):
			_fading[mesh] = 0.0
	for mesh in _fading.keys():
		if not is_instance_valid(mesh):
			_fading.erase(mesh)
			continue
		var goal := FADED if wanted.has(mesh) else 0.0
		var value: float = move_toward(_fading[mesh], goal, FADE_SPEED * delta)
		mesh.transparency = value
		if value == 0.0 and goal == 0.0:
			_fading.erase(mesh)
		else:
			_fading[mesh] = value


func is_faded(body: Node3D) -> bool:
	return _meshes_of(body).any(func(mesh): return _fading.get(mesh, 0.0) > 0.0)


## A body's own meshes, plus its roof slab (a sibling named <name>Roof).
func _meshes_of(body: Node3D) -> Array:
	var meshes := body.find_children("*", "MeshInstance3D", true, false)
	var roof := body.get_parent().get_node_or_null(String(body.name) + "Roof")
	if roof is MeshInstance3D:
		meshes.append(roof)
	return meshes


func _all_roofs() -> Array:
	return get_tree().root.find_children("*Roof", "MeshInstance3D", true, false)
