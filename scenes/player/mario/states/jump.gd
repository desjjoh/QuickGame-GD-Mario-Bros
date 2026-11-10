class_name MarioJumpState
extends PlayerState

@export var idle_state: PlayerState
@export var move_state: PlayerState


func enter() -> void:
	var player := get_player()
	player.air_movement.begin(
		player.motion_values,
		-1.0 if player.sprite != null and player.sprite.flip_h else 1.0,
		player.run_action.running_history
	)


func exit() -> void:
	var player := get_player()
	player.jump_action.end(player.motion_values)
	player.air_movement.end(player.motion_values)


func process_physics(delta: float) -> BaseState:
	var player := get_player() as Mario
	var direction := get_movement_axis().x
	player.jump_action.update(
		player.motion_values, controller_controls_available() and ControllerHandler.input_primary
	)
	var air_direction := direction
	if not player.form_controller.is_crouched:
		air_direction = player.terrain.filter_air_direction(direction)
	player.air_movement.apply(player.motion_values, air_direction, delta)
	player.move_body(true)
	if player.has_floor_support():
		return (
			move_state
			if not is_zero_approx(direction) or not is_zero_approx(player.body.velocity.x)
			else idle_state
		)
	return null
