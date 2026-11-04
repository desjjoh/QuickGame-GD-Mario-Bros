extends Node
## Global input source. States decide what the input means.
## Directions use UI actions; primary/secondary have dedicated bindings.

signal input_received(event: InputEvent)

@export var left_action: StringName = &"ui_left"
@export var right_action: StringName = &"ui_right"
@export var up_action: StringName = &"ui_up"
@export var down_action: StringName = &"ui_down"
@export var primary_action: StringName = &"primary"
@export var secondary_action: StringName = &"secondary"
## Title Start is bound; Select remains available for a future menu option.
@export var start_action: StringName = &"start"
@export var select_action: StringName = &""

var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled:
			_clear_input()

var input_left: float = 0.0
var input_right: float = 0.0
var input_up: float = 0.0
var input_down: float = 0.0
var input_primary: bool = false
var input_primary_just_pressed: bool = false
var input_secondary: bool = false
var input_start: bool = false
var input_start_just_pressed: bool = false
var _primary_requires_release: bool = false
var input_select: bool = false


func _ready() -> void:
	# Sample before ordinary entity physics callbacks.
	process_physics_priority = -100


func _physics_process(_delta: float) -> void:
	# Track release even while transitions suppress gameplay intent.
	if _primary_requires_release and not Input.is_action_pressed(primary_action):
		_primary_requires_release = false
	if not enabled:
		return
	input_left = Input.get_action_strength(left_action)
	input_right = Input.get_action_strength(right_action)
	input_up = Input.get_action_strength(up_action)
	input_down = Input.get_action_strength(down_action)
	if _primary_requires_release:
		input_primary = false
		input_primary_just_pressed = false
	else:
		input_primary = Input.is_action_pressed(primary_action)
		input_primary_just_pressed = Input.is_action_just_pressed(primary_action)
	input_secondary = _is_action_pressed(secondary_action)
	input_start = _is_action_pressed(start_action)
	input_start_just_pressed = start_action != &"" and InputMap.has_action(start_action) and Input.is_action_just_pressed(start_action)
	input_select = _is_action_pressed(select_action)


func _unhandled_input(event: InputEvent) -> void:
	if enabled and not event.is_echo():
		input_received.emit(event)


func get_axis() -> Vector2:
	return Vector2(input_right - input_left, input_down - input_up)


func _is_action_pressed(action: StringName) -> bool:
	return action != &"" and InputMap.has_action(action) and Input.is_action_pressed(action)


func consume_menu_confirmation() -> void:
	_primary_requires_release = Input.is_action_pressed(primary_action)
	input_primary = false
	input_primary_just_pressed = false
	input_start_just_pressed = false

func _clear_input() -> void:
	input_left = 0.0
	input_right = 0.0
	input_up = 0.0
	input_down = 0.0
	input_primary = false
	input_primary_just_pressed = false
	input_secondary = false
	input_start = false
	input_start_just_pressed = false
	input_select = false
