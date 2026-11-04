class_name JumpAction
extends Node

signal jumped

@export var sound_effect: AudioStream

@export var speed_thresholds := PackedFloat32Array([33.75, 60, 93.75, 105])
@export var jump_speeds := PackedFloat32Array([240, 240, 240, 300, 300])
@export var rising_gravities := PackedFloat32Array([450, 450, 421.875, 562.5, 562.5])
@export var falling_gravities := PackedFloat32Array([1575, 1575, 1350, 2025, 2025])
@export var minimum_release_height: float = 1.0

var active: bool = false
var _origin_y: float
var _rise: float
var _fall: float
var _released: bool = false


func begin(values: MotionValues) -> bool:
	if not values.body.is_on_floor():
		return false
	if (
		jump_speeds.size() != speed_thresholds.size() + 1
		or rising_gravities.size() != jump_speeds.size()
		or falling_gravities.size() != jump_speeds.size()
	):
		push_error("Jump arrays must contain one value per speed band.")
		return false
	var profile := 0
	for threshold in speed_thresholds:
		if absf(values.velocity.x) >= threshold:
			profile += 1
	_origin_y = values.body.global_position.y
	_rise = rising_gravities[profile]
	_fall = falling_gravities[profile]
	_released = false
	active = true
	var velocity := values.velocity
	velocity.y = -jump_speeds[profile]
	values.velocity = velocity
	update(values, true)
	jumped.emit()
	return true


func update(values: MotionValues, held: bool) -> void:
	if not active:
		return
	if not held and _origin_y - values.body.global_position.y >= minimum_release_height:
		_released = true
	values.set_modifier(
		&"jump", {&"gravity": _fall if _released or values.velocity.y >= 0.0 else _rise}, 250
	)


func end(values: MotionValues) -> void:
	active = false
	values.remove_modifier(&"jump")
