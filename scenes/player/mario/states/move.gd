class_name MarioMoveState
extends PlayerState
## Walk/run and passive falling. Deliberate jumps use MarioJumpState.

@export var idle_state: PlayerState
@export var slide_state: PlayerState
@export var jump_state: PlayerState

var _previous_animation_speed: float = 1.0
var _falling: bool = false
var _defer_growth_vertical := false


func defer_growth_fall_step() -> void:
	_defer_growth_vertical = true


func enter() -> void:
	_falling = false
	var mario := get_player() as Mario
	_previous_animation_speed = mario.animation_player.speed_scale
	_update_walk_animation(mario)

	# Apply the initial texture now rather than waiting for another animation tick.
	mario.animation_player.advance(0.0)


func exit() -> void:
	_defer_growth_vertical = false
	if _falling:
		get_player().air_movement.end(get_player().motion_values)
		get_player().motion_values.remove_modifier(&"passive_fall")
		_falling = false
	get_player().animation_player.speed_scale = _previous_animation_speed


func process_physics(delta: float) -> BaseState:
	var player := get_player()
	var direction := prepare_horizontal_motion()
	var next := ground_transition(jump_state, self)
	if next != null:
		return continue_physics(next, delta)
	if not player.body.is_on_floor():
		return _process_falling(player, direction, delta)

	if player.slide_action.can_start(player.body, direction):
		return continue_physics(slide_state, delta)

	# Low-speed reversal finishes immediately instead of entering a visible skid.
	if player.slide_action.is_opposing(player.body, direction):
		player.body.velocity.x = 0.0

	player.horizontal_movement.apply(player.body, player.motion_values, direction, delta)
	player.face_direction(direction)
	player.vertical_movement.apply_gravity(player.motion_values, delta)
	player.move_body()

	var mario := player as Mario
	_update_walk_animation(mario)

	if is_zero_approx(direction) and is_zero_approx(player.body.velocity.x):
		return idle_state

	return null


func _process_falling(player: BasePlayer, direction: float, delta: float) -> BaseState:
	if not _falling:
		player.air_movement.begin(
			player.motion_values,
			-1.0 if player.sprite != null and player.sprite.flip_h else 1.0,
			player.run_action.running_history
		)
		_falling = true
		player.motion_values.set_modifier(
			&"passive_fall", {&"gravity": player.jump_action.falling_gravity}, 250
		)
	player.air_movement.apply(player.motion_values, direction, delta)
	if _defer_growth_vertical:
		# NES growth first runs a ground-control tick, then detects the fall.
		# Retain upward momentum; vertical integration starts on the next tick.
		_defer_growth_vertical = false
		var vertical_speed := player.body.velocity.y
		player.body.velocity.y = 0.0
		player.move_body()
		player.body.velocity.y = vertical_speed
	else:
		player.move_body(true)
	var mario := player as Mario
	_update_walk_animation(mario)
	if player.body.is_on_floor():
		player.air_movement.end(player.motion_values)
		player.motion_values.remove_modifier(&"passive_fall")
		_falling = false
		if is_zero_approx(direction) and is_zero_approx(player.body.velocity.x):
			return idle_state
	return null


func _update_walk_animation(mario: Mario) -> void:
	if mario.body.is_on_floor():
		mario.walk_animation.apply(mario.animation_player, mario.body.velocity.x)
	else:
		# Preserve both the current texture and loop position during passive falls.
		mario.animation_player.speed_scale = 0.0
