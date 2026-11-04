class_name MotionValues
extends Node
## Per-entity defaults and named overrides shared across states.
## Velocity proxies Body; it is never stored a second time.

@export var body: CharacterBody2D
@export var base_max_speed: float = 90.0
@export var base_acceleration: float = 133.59375
@export var base_deceleration: float = 133.59375
@export var base_reversal_multiplier: float = 2.0
@export var base_gravity: float = 1575.0
@export var base_weight: float = 1.0
@export var base_max_fall_speed: float = 240.0

var gravity: float:
	get:
		return _resolve(&"gravity", base_gravity)

var weight: float:
	get:
		return _resolve(&"weight", base_weight)

var max_fall_speed: float:
	get:
		return _resolve(&"max_fall_speed", base_max_fall_speed)

var _modifiers: Dictionary[StringName, Dictionary] = {}

var velocity: Vector2:
	get:
		return body.velocity
	set(value):
		body.velocity = value

var max_speed: float:
	get:
		return _resolve(&"max_speed", base_max_speed)

var acceleration: float:
	get:
		return _resolve(&"acceleration", base_acceleration)

var deceleration: float:
	get:
		return _resolve(&"deceleration", base_deceleration)

var reversal_multiplier: float:
	get:
		return _resolve(&"reversal_multiplier", base_reversal_multiplier)


func set_modifier(
	source: StringName, values: Dictionary[StringName, float], priority: int = 0
) -> void:
	for key: StringName in values:
		if (
			key
			not in [
				&"max_speed",
				&"acceleration",
				&"deceleration",
				&"reversal_multiplier",
				&"gravity",
				&"weight",
				&"max_fall_speed"
			]
		):
			push_error("Unknown motion value: %s" % key)
			return
		if not is_finite(values[key]) or values[key] < 0.0:
			push_error("Motion values must be finite and nonnegative.")
			return
	_modifiers[source] = {"values": values.duplicate(), "priority": priority}


func remove_modifier(source: StringName) -> void:
	_modifiers.erase(source)


func _resolve(key: StringName, fallback: float) -> float:
	var result := fallback
	var priority := -2147483648
	var sources := _modifiers.keys()
	sources.sort()
	for source: StringName in sources:
		var modifier: Dictionary = _modifiers[source]
		var values: Dictionary = modifier["values"]
		if values.has(key) and int(modifier["priority"]) >= priority:
			result = values[key]
			priority = modifier["priority"]
	return result
