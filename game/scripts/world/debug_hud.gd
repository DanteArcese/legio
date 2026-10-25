extends CanvasLayer
## Prototype overlay: tick counter, tick length, and a pulse on every tick.

@export var driver: Node

@onready var _label: Label = $Label
@onready var _pulse: ColorRect = $Pulse


func _ready() -> void:
	driver.ticked.connect(_on_ticked)
	_on_ticked(0)


func _on_ticked(tick: int) -> void:
	_label.text = "Tick %d   |   %.1f s per tick (F3 to change)" % [tick, driver.clock.tick_length]
	_pulse.modulate.a = 1.0
	create_tween().tween_property(_pulse, "modulate:a", 0.0, 0.25)
