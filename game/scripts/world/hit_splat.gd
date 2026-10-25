extends Label3D
## Floating damage number shown above an entity when it is hit.

const RISE := 0.8
const DURATION := 0.9


static func spawn(over: Node3D, damage: int) -> void:
	var splat := new()
	splat.text = str(damage)
	splat.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	splat.no_depth_test = true
	splat.font_size = 64
	splat.outline_size = 12
	splat.modulate = Color(0.9, 0.15, 0.1) if damage > 0 else Color(0.25, 0.5, 0.95)
	splat.position = Vector3(randf_range(-0.2, 0.2), 1.6, 0.0)
	over.add_child(splat)


func _ready() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y + RISE, DURATION)
	tween.tween_property(self, "modulate:a", 0.0, DURATION).set_delay(DURATION * 0.4)
	tween.chain().tween_callback(queue_free)
