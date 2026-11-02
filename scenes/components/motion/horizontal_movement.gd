class_name HorizontalMovementComponent
extends Node
## Adjusts horizontal velocity only. The state owns when the body moves.

func apply(body: CharacterBody2D, values: MotionValues, direction: float, delta: float) -> void:
	var target := clampf(direction, -1.0, 1.0) * values.max_speed
	var rate := values.deceleration if is_zero_approx(direction) else values.acceleration
	
	if not is_zero_approx(direction) and body.velocity.x * direction < 0.0:
		rate *= values.reversal_multiplier
		
	body.velocity.x = move_toward(body.velocity.x, target, rate * delta)

