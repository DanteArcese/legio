extends Node
## Autoload that installs the default bindings at startup.

const Bindings := preload("res://scripts/input/bindings.gd")


func _enter_tree() -> void:
	Bindings.apply()
