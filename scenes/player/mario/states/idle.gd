class_name MarioIdleState
extends PlayerState
## Idle yields to Move when input or horizontal momentum needs processing.

@export var move_state: PlayerState
@export var jump_state: PlayerState


func process_physics(delta: float) -> BaseState:
	var player := get_player()
	var direction := prepare_horizontal_motion()
	var next := ground_transition(jump_state, move_state)
	if next != null:
		return continue_physics(next, delta)
	if not is_zero_approx(direction) or not is_zero_approx(player.body.velocity.x):
		return continue_physics(move_state, delta)
	player.body.velocity.y = 0.0
	player.move_body()
	return null
