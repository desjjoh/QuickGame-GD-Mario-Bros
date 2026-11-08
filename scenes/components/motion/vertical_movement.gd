class_name VerticalMovementComponent
extends Node
## NES airborne integration at 60Hz. Body velocity publishes the encoded speed.
var integer_speed := 0
var speed_fraction := 0
var position_fraction := 0
var _published := NAN
var _fixed_step := false
var _target_y := 0.0


func reset_fraction(body: CharacterBody2D = null) -> void:
	position_fraction = 0
	if body != null:
		body.global_position.y = roundf(body.global_position.y)
	_published = NAN


func apply_gravity(values: MotionValues, delta: float) -> void:
	var velocity := values.velocity
	velocity.y = speed_after_gravity(values, delta)
	values.velocity = velocity


func speed_after_gravity(values: MotionValues, delta: float) -> float:
	return minf(values.velocity.y + values.gravity * values.weight * delta, values.max_fall_speed)


## Prepare integer displacement and next speed without moving the body twice.
func prepare_step(values: MotionValues, delta: float) -> float:
	var force := values.gravity * values.weight / 3600.0 * 256.0
	_fixed_step = (
		is_equal_approx(delta, 1.0 / 60.0)
		and force >= 0
		and force <= 255
		and is_equal_approx(force, roundf(force))
		and is_equal_approx(values.max_fall_speed / 60.0, roundf(values.max_fall_speed / 60.0))
	)
	if not _fixed_step:
		return speed_after_gravity(values, delta)
	var current := values.velocity.y
	if is_nan(_published) or not is_equal_approx(current, _published):
		var units := int(roundf(current / 60.0 * 256.0))
		integer_speed = floori(units / 256.0)
		speed_fraction = posmod(units, 256)
	var accumulated := position_fraction + speed_fraction
	var displacement := integer_speed + (1 if accumulated >= 256 else 0)
	position_fraction = accumulated % 256
	var next_units := integer_speed * 256 + speed_fraction + int(roundf(force))
	var limit := int(roundf(values.max_fall_speed / 60.0))
	# ImposeGravity allows the low half of the cap's fractional range.
	if next_units >= limit * 256 + 128:
		next_units = limit * 256
	integer_speed = floori(next_units / 256.0)
	speed_fraction = posmod(next_units, 256)
	var next_speed := next_units / 256.0 * 60.0
	_target_y = roundf(values.body.global_position.y) + displacement
	values.body.velocity.y = (_target_y - values.body.global_position.y) / delta
	return next_speed


func finish_step(values: MotionValues, next_speed: float) -> void:
	# Keep integer NES position when Godot applies a subpixel safe-margin recovery.
	# Never override an actual floor/ceiling collision or a larger obstruction.
	if _fixed_step and not values.body.is_on_floor() and not values.body.is_on_ceiling():
		if absf(values.body.global_position.y - _target_y) < 0.5:
			values.body.global_position.y = _target_y
	var velocity := values.velocity
	velocity.y = 0.0 if values.body.is_on_floor() else next_speed
	values.velocity = velocity
	_published = velocity.y
	if values.body.is_on_floor():
		integer_speed = 0
		speed_fraction = 0


## A collision writes only the integer speed byte; both fractional registers survive.
func speed_with_integer(values: MotionValues, speed: int) -> float:
	var units := int(roundf(values.velocity.y / 60.0 * 256.0))
	return (speed * 256 + posmod(units, 256)) / 256.0 * 60.0
