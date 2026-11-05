class_name GravityComponent
extends Node


func apply(values: MotionValues, delta: float) -> void:
	var velocity := values.velocity
	velocity.y = vertical_speed_after(values, delta)
	values.velocity = velocity


func vertical_speed_after(values: MotionValues, delta: float) -> float:
	return minf(values.velocity.y + values.gravity * values.weight * delta, values.max_fall_speed)
