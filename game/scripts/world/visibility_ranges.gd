extends Node
## Stops drawing small things far away. Depth fog hides the world beyond
## about 150 m, but the GPU would draw it all anyway: every barrel, bush and
## monster in every region. At startup (after the regions are dressed) and
## whenever a mesh is added later (monster bodies, loot, the munera's
## beasts), each mesh gets a visibility range by its size: the smaller it
## is, the sooner it stops being drawn. Large things (walls, buildings,
## terrain) keep no range, and anything that already set one keeps its own.

## [largest radius in metres, stop drawing beyond this many metres].
const RANGES := [[1.0, 70.0], [3.0, 100.0], [8.0, 140.0]]
## Hysteresis, so a mesh at the edge doesn't flicker as the camera moves.
const MARGIN := 6.0

@export var root: Node


func _ready() -> void:
	if root == null:
		root = get_parent()
	# Regions build and dress themselves in their own _ready; wait for them.
	_apply_all.call_deferred()
	get_tree().node_added.connect(_on_node_added)


func _apply_all() -> void:
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		apply(node)


func _on_node_added(node: Node) -> void:
	if node is GeometryInstance3D:
		# Meshes are often assigned just after the node enters the tree.
		apply.call_deferred(node)


## Sets a mesh's visibility range from its size (see RANGES).
func apply(node: GeometryInstance3D) -> void:
	if not is_instance_valid(node) or node.visibility_range_end > 0.0:
		return
	if node is Label3D or node is MultiMeshInstance3D:
		return
	var aabb := node.get_aabb()
	# No geometry yet: judging it now would cull something large too soon.
	if aabb.size == Vector3.ZERO:
		return
	var basis := node.global_transform.basis if node.is_inside_tree() else node.transform.basis
	var end := range_for(aabb, basis.get_scale())
	if end > 0.0:
		node.visibility_range_end = end
		node.visibility_range_end_margin = MARGIN


## The range for a mesh of this local size and scale, or 0 for "always".
static func range_for(aabb: AABB, scale: Vector3) -> float:
	var radius := (aabb.size * scale.abs()).length() / 2.0
	for entry in RANGES:
		if radius <= entry[0]:
			return entry[1]
	return 0.0
