extends "res://tests/test_case.gd"
## Visibility ranges by size: small things stop drawing sooner.

const VisibilityRanges := preload("res://scripts/world/visibility_ranges.gd")


func test_ranges_by_size() -> void:
	check_eq(VisibilityRanges.range_for(AABB(Vector3.ZERO, Vector3(0.5, 0.5, 0.5)), Vector3.ONE), 70.0, "a barrel")
	check_eq(VisibilityRanges.range_for(AABB(Vector3.ZERO, Vector3(2, 3, 2)), Vector3.ONE), 100.0, "a cart")
	check_eq(VisibilityRanges.range_for(AABB(Vector3.ZERO, Vector3(8, 6, 8)), Vector3.ONE), 140.0, "a house")
	check_eq(VisibilityRanges.range_for(AABB(Vector3.ZERO, Vector3(40, 4, 1)), Vector3.ONE), 0.0, "a wall always draws")
	check_eq(VisibilityRanges.range_for(AABB(Vector3.ZERO, Vector3(0.5, 0.5, 0.5)), Vector3(10, 10, 10)), 140.0, "scale counts")


func test_apply_keeps_existing_ranges() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var ranges := VisibilityRanges.new()
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	var label := MeshInstance3D.new()
	label.mesh = BoxMesh.new()
	label.visibility_range_end = 30.0
	tree.root.add_child(box)
	tree.root.add_child(label)
	ranges.apply(box)
	ranges.apply(label)
	check_eq(box.visibility_range_end, 70.0, "a 1 m box gets the small range")
	check_eq(label.visibility_range_end, 30.0, "its own range kept")
	box.free()
	label.free()
	ranges.free()
