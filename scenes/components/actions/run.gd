class_name RunAction
extends Node
## Changes shared motion parameters; it never moves the body itself.

@export var max_speed: float = 150.0
@export var acceleration: float = 200.390625
@export var deceleration: float = 200.390625
@export var modifier_priority: int = 100
@export_range(0, 60, 1) var retention_ticks: int = 10

@export var neutral_acceleration: float = 133.59375
@export var history_acceleration: float = 182.8125
@export var history_speed_threshold: float = 105.0
@export var neutral_fast_threshold: float = 123.75
@export var held_action_stop_speed: float = 41.25

var remaining_ticks: int = 0
var running_history: bool = false


func apply(values: MotionValues, pressed: bool) -> void:
	if pressed:
		(
			values
			. set_modifier(
				&"run",
				{
					&"max_speed": max_speed,
					&"acceleration": acceleration,
					&"deceleration": deceleration,
				},
				modifier_priority
			)
		)
	else:
		values.remove_modifier(&"run")


func advance_timer() -> void:
	# Called once before state physics, never from a state-to-state handoff.
	remaining_ticks = maxi(remaining_ticks - 1, 0)


func prepare_ground_profile(
	values: MotionValues,
	pressed: bool,
	direction: float,
	grounded: bool,
	facing: float,
	stop_input_held: bool = false,
	raw_direction: float = 0.0
) -> void:
	values.remove_modifier(&"ground_neutral")
	var moving_direction := (
		signf(values.velocity.x) if not is_zero_approx(values.velocity.x) else facing
	)
	var continuing_direction := not is_zero_approx(direction) and direction * moving_direction > 0.0
	if grounded and continuing_direction:
		if pressed:
			remaining_ticks = retention_ticks
		apply(values, pressed or remaining_ticks > 0)
	else:
		apply(values, pressed)
	if not grounded:
		return
	var speed := absf(values.velocity.x)
	if is_zero_approx(direction):
		# ChkRFast selects friction independently of B when no direction is held.
		var rate := (
			history_acceleration
			if running_history or speed >= neutral_fast_threshold
			else neutral_acceleration
		)
		if not is_zero_approx(values.velocity.x) and moving_direction != facing:
			rate *= 2.0
		values.set_modifier(
			&"ground_neutral", {&"acceleration": rate, &"deceleration": rate}, modifier_priority + 1
		)
		# GetPlayerAnimSpeed reads raw direction even after grounded diagonal
		# filtering. Down alone/opposite direction stops low speed; holding the
		# movement direction preserves coasting, including with Down or B.
		if speed >= history_speed_threshold:
			running_history = true
		elif (
			(pressed or stop_input_held)
			and raw_direction * moving_direction <= 0.0
			and speed < held_action_stop_speed
		):
			var velocity := values.velocity
			velocity.x = 0.0
			values.velocity = velocity
	elif speed >= history_speed_threshold:
		running_history = true
	elif continuing_direction:
		running_history = false
