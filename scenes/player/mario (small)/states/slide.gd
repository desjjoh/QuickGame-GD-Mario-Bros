class_name MarioSlideState
extends PlayerState

## Faces opposite momentum while the Slide action brakes the physical body.

@export var move_state: PlayerState
@export var idle_state: PlayerState
@export var jump_state: PlayerState


func enter() -> void:
	var player := get_player()
	player.slide_action.begin(player.motion_values)
	player.face_direction(get_movement_axis().x)


func exit() -> void:
	var player := get_player()
	player.slide_action.end(player.motion_values)


func process_physics(delta: float) -> BaseState:
	var player := get_player()
	var direction := prepare_horizontal_motion()
	var next := ground_transition(jump_state, move_state)
	if next != null:
		return continue_physics(next, delta)
	if is_zero_approx(player.body.velocity.x):
		return continue_physics(move_state if not is_zero_approx(direction) else idle_state, delta)
	# Neutral input preserves the skid and facing until braking completes.
	# Only actively resuming the momentum direction cancels the reversal.
	if (
		not is_zero_approx(direction)
		and not player.slide_action.is_opposing(player.body, direction)
	):
		return continue_physics(move_state, delta)
	player.face_direction(direction)
	var stopped := player.slide_action.apply(player.motion_values, delta)
	player.gravity_component.apply(player.motion_values, delta)
	player.move_body()
	# A solid wall stops physical velocity immediately, but retain this tick's
	# skid pose using the pre-collision braking result. Resolve it next tick.
	if stopped:
		return move_state if not is_zero_approx(direction) else idle_state
	return null
