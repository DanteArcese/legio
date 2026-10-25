extends Node
## Bakes a navigation mesh at startup from the static world (terrain,
## buildings, trees, props) and offers path queries to the player, monsters,
## and click-to-move. Nodes opt in by joining the "navigation_source" group.

const SOURCE_GROUP := "navigation_source"
## Terrain and buildings (1) plus props and NPCs (8).
const SOURCE_COLLISION_MASK := 1 | 8
const AGENT_RADIUS := 0.5
## Waypoints closer than this are treated as reached.
const WAYPOINT_REACHED := 0.4

var region: NavigationRegion3D


func _ready() -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = SOURCE_COLLISION_MASK
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = SOURCE_GROUP
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.agent_radius = AGENT_RADIUS
	mesh.agent_height = 1.8
	mesh.agent_max_climb = 0.25
	region = NavigationRegion3D.new()
	region.navigation_mesh = mesh
	add_child(region)
	region.bake_navigation_mesh(false)


## The next point to walk toward on the way from one position to another.
## Falls back to a straight line if no path is available yet.
static func next_waypoint(world: World3D, from: Vector3, to: Vector3) -> Vector3:
	var path := NavigationServer3D.map_get_path(world.navigation_map, from, to, true)
	for point in path:
		if Vector2(point.x - from.x, point.z - from.z).length() > WAYPOINT_REACHED:
			return point
	return to


## The closest walkable point to a position (for clicks on obstacles).
static func closest_walkable(world: World3D, to: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(world.navigation_map, to)
