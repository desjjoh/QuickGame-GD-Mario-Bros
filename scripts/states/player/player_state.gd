class_name PlayerState
extends EntityState
## Shared player-state behavior. Concrete characters own their state nodes.

@export_group("Controls")
@export var controls_enabled: bool = true


func get_player() -> BasePlayer:
	return entity as BasePlayer


func controller_controls_available() -> bool:
	var player := get_player()
	return controls_enabled and is_instance_valid(player) and player.can_read_controller_input()


func get_movement_axis() -> Vector2:
	return ControllerHandler.get_axis() if controller_controls_available() else Vector2.ZERO


func prepare_horizontal_motion() -> float:
	# Grounded states call this before ground_transition so takeoff captures
	# this tick's Run modifier, including simultaneous Run/Jump changes.
	var player := get_player()
	var direction := get_movement_axis().x
	var facing := -1.0 if player.sprite != null and player.sprite.flip_h else 1.0
	player.run_action.prepare_ground_profile(
		player.motion_values,
		controller_controls_available() and ControllerHandler.input_secondary,
		direction,
		player.body.is_on_floor(),
		facing
	)
	return direction


func ground_transition(jump_state: PlayerState, falling_state: PlayerState) -> BaseState:
	var player := get_player()
	if not player.body.is_on_floor():
		if falling_state != self:
			player.air_movement.capture(
				player.motion_values,
				-1.0 if player.sprite != null and player.sprite.flip_h else 1.0,
				player.run_action.running_history
			)
			return falling_state
		return null
	if controller_controls_available() and ControllerHandler.input_primary_just_pressed:
		if player.jump_action.begin(player.motion_values):
			player.air_movement.capture(
				player.motion_values,
				-1.0 if player.sprite != null and player.sprite.flip_h else 1.0,
				player.run_action.running_history
			)
			return jump_state
	return null


func continue_physics(next_state: BaseState, delta: float) -> BaseState:
	# Use only before this tick has integrated the body. Enter the next state
	# first so its motion profile owns the one remaining integration step.
	if not state_machine.change_state(next_state):
		return null
	if (
		entity.is_shutdown
		or state_machine.current_state != next_state
		or not next_state.physics_updates_enabled
	):
		return null
	return next_state.process_physics(delta)
