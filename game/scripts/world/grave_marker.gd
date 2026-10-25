extends Node3D
## Gravestone shown where the player died, with time left before the
## libitinarii collect it. Mirrors the simulation's grave.

const TICK_SECONDS := 0.6

var expires_at := 0
var driver: Node

var _label: Label3D


static func spawn(parent: Node, p_driver: Node, at: Vector3, p_expires_at: int) -> Node3D:
	var marker := new()
	marker.driver = p_driver
	marker.expires_at = p_expires_at
	marker.add_to_group("graves")
	parent.add_child(marker)
	marker.global_position = Vector3(at.x, 0.0, at.z)
	return marker


func _ready() -> void:
	var stone := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.9, 0.2)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.55, 0.58)
	box.material = material
	stone.mesh = box
	stone.position.y = 0.45
	add_child(stone)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 36
	_label.outline_size = 8
	_label.position.y = 1.3
	add_child(_label)
	driver.ticked.connect(_on_ticked)
	_on_ticked(driver.sim.tick)


func _on_ticked(tick: int) -> void:
	var seconds := maxi(expires_at - tick, 0) * TICK_SECONDS
	_label.text = "Your grave\n%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
