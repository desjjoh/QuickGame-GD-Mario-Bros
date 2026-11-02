class_name SlideAction
extends Node
## Ground reversal/skid, not a crouching slide. Braking never crosses zero.

@export var minimum_speed: float = 41.25
@export var stop_speed: float = 41.25
@export var fast_speed_threshold: float = 105.0
@export var normal_friction: float = 133.59375
@export var fast_friction: float = 182.8125
@export var reversal_multiplier: float = 2.0
@export var max_speed: float = 90.0
@export var modifier_priority: int = 300


func is_opposing(body: CharacterBody2D, direction: float) -> bool:
	return body.velocity.x * direction < 0.0


func can_start(body: CharacterBody2D, direction: float) -> bool:
	return is_opposing(body, direction) and absf(body.velocity.x) >= minimum_speed


func begin(values: MotionValues) -> void:
	var friction := fast_friction if absf(values.velocity.x) >= fast_speed_threshold else normal_friction
	values.set_modifier(&"slide", {
		&"max_speed": max_speed,
		&"acceleration": friction,
		&"deceleration": friction,
		&"reversal_multiplier": reversal_multiplier,
	}, modifier_priority)


func apply(values: MotionValues, delta: float) -> bool:
	var velocity := values.velocity
	velocity.x = move_toward(velocity.x, 0.0, values.acceleration * values.reversal_multiplier * delta)
	if absf(velocity.x) < stop_speed:
		velocity.x = 0.0
	values.velocity = velocity
	return is_zero_approx(velocity.x)


func end(values: MotionValues) -> void:
	values.remove_modifier(&"slide")
