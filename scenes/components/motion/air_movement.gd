class_name AirMovementComponent
extends Node
## Separate air profile; neutral input preserves momentum.

@export var fast_speed_threshold: float = 93.75
@export var history_speed_threshold: float = 105.0
@export var normal_acceleration: float = 133.59375
@export var history_acceleration: float = 182.8125
@export var fast_acceleration: float = 200.390625
@export var normal_max_speed: float = 90.0
@export var fast_max_speed: float = 150.0
@export var facing_mismatch_multiplier: float = 2.0

var _captured: bool = false
var _fast_history: bool = false
var _facing: float = 1.0


func capture(values: MotionValues, facing: float) -> void:
	_facing = facing
	_fast_history = absf(values.velocity.x) >= history_speed_threshold or is_equal_approx(values.acceleration, history_acceleration)
	_captured = true


func begin(values: MotionValues, facing: float) -> void:
	if not _captured:
		capture(values, facing)
	update_profile(values)


func update_profile(values: MotionValues) -> void:
	var fast := absf(values.velocity.x) >= fast_speed_threshold
	var rate := fast_acceleration if fast else (history_acceleration if _fast_history else normal_acceleration)
	if not is_zero_approx(values.velocity.x) and signf(values.velocity.x) != _facing:
		rate *= facing_mismatch_multiplier
	values.set_modifier(&"air", {
		&"max_speed": fast_max_speed if fast else normal_max_speed,
		&"acceleration": rate,
		&"deceleration": 0.0,
		&"reversal_multiplier": 1.0,
	}, 300)


func apply(values: MotionValues, direction: float, delta: float) -> void:
	update_profile(values)
	if is_zero_approx(direction):
		return
	var velocity := values.velocity
	var change := values.acceleration * clampf(direction, -1.0, 1.0) * delta
	velocity.x = minf(velocity.x + change, values.max_speed) if direction > 0.0 else maxf(velocity.x + change, -values.max_speed)
	values.velocity = velocity


func end(values: MotionValues) -> void:
	values.remove_modifier(&"air")
	_captured = false

