class_name RunAction
extends Node
## Changes shared motion parameters; it never moves the body itself.

@export var max_speed: float = 150.0
@export var acceleration: float = 200.390625
@export var deceleration: float = 200.390625
@export var modifier_priority: int = 100


func apply(values: MotionValues, pressed: bool) -> void:
	if pressed:
		values.set_modifier(&"run", {
			&"max_speed": max_speed,
			&"acceleration": acceleration,
			&"deceleration": deceleration,
		}, modifier_priority)
	else:
		values.remove_modifier(&"run")
