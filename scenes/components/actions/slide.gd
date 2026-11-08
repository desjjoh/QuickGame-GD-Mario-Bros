class_name SlideAction
extends Node
## Ground reversal: select friction before facing changes; reset before acceleration.

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


func begin(values: MotionValues, running_history: bool = false) -> void:
	var friction := (
		fast_friction
		if running_history or absf(values.velocity.x) >= fast_speed_threshold
		else normal_friction
	)
	(
		values
		. set_modifier(
			&"slide",
			{
				&"max_speed": max_speed,
				&"acceleration": friction,
				&"deceleration": friction,
				&"reversal_multiplier": reversal_multiplier,
			},
			modifier_priority
		)
	)


func apply(values: MotionValues, delta: float, direction: float, previous_facing: float) -> bool:
	var velocity := values.velocity
	var moving_direction := signf(velocity.x)
	var rate := values.acceleration
	if not is_zero_approx(moving_direction) and moving_direction != previous_facing:
		rate *= values.reversal_multiplier
	# GetPlayerAnimSpeed resets low speed before ImposeFriction runs.
	var reset := absf(velocity.x) < stop_speed
	if reset:
		velocity.x = direction * rate * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, rate * delta)
	values.velocity = velocity
	return reset


func end(values: MotionValues) -> void:
	values.remove_modifier(&"slide")
