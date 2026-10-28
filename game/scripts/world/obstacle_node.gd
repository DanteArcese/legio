extends StaticBody3D
## One obstacle of an Athletics course. Players start it from this node's
## position and finish at end_offset. Builds its own look: a log, a
## palisade wall, a rope swing over a ditch, a row of hurdles, or a ladder
## up a wall (a shortcut).

const ContentDB := preload("res://scripts/content/content_db.gd")
const WOOD := Color(0.45, 0.32, 0.2)
const ROPE := Color(0.7, 0.6, 0.4)

@export var course := "fort_course"
@export var index := 0
## Where a crossing ends, relative to this node (in world axes).
@export var end_offset := Vector3(0, 0, 6)

var obstacle_id := 0


func _init() -> void:
	collision_layer = 8
	add_to_group("obstacles")


## A marker at the far end, so the terrain flattens there too. All nodes
## enter the tree before the terrain's _ready reads the groups.
func _enter_tree() -> void:
	if has_node("End"):
		return
	var marker := Node3D.new()
	marker.name = "End"
	marker.position = end_offset
	marker.add_to_group("obstacle_ends")
	add_child(marker)


func _ready() -> void:
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.shape.radius = 0.5
	shape.position.y = 0.4
	add_child(shape)
	var visual := Node3D.new()
	add_child(visual)
	# The obstacle runs from here toward the end point.
	var flat := Vector3(end_offset.x, 0, end_offset.z)
	visual.rotation.y = atan2(flat.x, flat.z)
	var length := flat.length()
	match data()["kind"]:
		"log":
			var log_mesh := _cylinder(0.22, length, WOOD)
			log_mesh.rotation.x = PI / 2.0
			log_mesh.position = Vector3(0, 0.25, length / 2.0)
			visual.add_child(log_mesh)
		"wall":
			var wall := _box(Vector3(2.4, 1.9, 0.3), WOOD)
			wall.position = Vector3(0, 0.95, length / 2.0)
			visual.add_child(wall)
			for x in [-1.0, 0.0, 1.0]:
				var stake := _cylinder(0.1, 2.3, WOOD.darkened(0.2))
				stake.position = Vector3(x, 1.15, length / 2.0)
				visual.add_child(stake)
		"rope":
			var post := _cylinder(0.12, 3.4, WOOD)
			post.position = Vector3(0, 1.7, length / 2.0)
			visual.add_child(post)
			var beam := _cylinder(0.08, 1.6, WOOD)
			beam.rotation.x = PI / 2.0
			beam.position = Vector3(0, 3.4, length / 2.0 - 0.8)
			visual.add_child(beam)
			var rope := _cylinder(0.03, 2.4, ROPE)
			rope.position = Vector3(0, 2.2, length / 2.0 - 1.6)
			visual.add_child(rope)
			var ditch := _box(Vector3(2.6, 0.05, length * 0.6), Color(0.28, 0.22, 0.15))
			ditch.position = Vector3(0, 0.03, length / 2.0)
			visual.add_child(ditch)
		"climb":
			# A ladder leaning on the wall just ahead.
			for x in [-0.35, 0.35]:
				var rail := _cylinder(0.05, 3.6, WOOD)
				rail.position = Vector3(x, 1.7, 0.9)
				rail.rotation.x = -0.25
				visual.add_child(rail)
			for i in 7:
				var rung := _cylinder(0.035, 0.7, WOOD.darkened(0.15))
				rung.rotation.z = PI / 2.0
				rung.position = Vector3(0, 0.35 + i * 0.48, 0.98 - i * 0.12)
				visual.add_child(rung)
		"hurdles":
			for i in 3:
				var z := length * (i + 1) / 4.0
				var bar := _cylinder(0.06, 1.6, WOOD)
				bar.rotation.z = PI / 2.0
				bar.position = Vector3(0, 0.6, z)
				visual.add_child(bar)
				for x in [-0.8, 0.8]:
					var leg := _cylinder(0.05, 0.6, WOOD.darkened(0.2))
					leg.position = Vector3(x, 0.3, z)
					visual.add_child(leg)
	var label := Label3D.new()
	label.text = display_name()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.outline_size = 8
	label.position.y = 2.2
	label.visibility_range_end = 30.0
	add_child(label)


func data() -> Dictionary:
	return ContentDB.course(course)["obstacles"][index]


func display_name() -> String:
	return data()["name"]


func verb() -> String:
	return data()["verb"]


func end_position() -> Vector3:
	return global_position + end_offset


static func _cylinder(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.material = _material(color)
	mesh.mesh = cylinder
	return mesh


static func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = _material(color)
	mesh.mesh = box
	return mesh


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
