class_name GravityComponent
extends Node


func apply(values: MotionValues, delta: float) -> void:
	var velocity := values.velocity
	velocity.y = minf(velocity.y + values.gravity * values.weight * delta, values.max_fall_speed)
	values.velocity = velocity
