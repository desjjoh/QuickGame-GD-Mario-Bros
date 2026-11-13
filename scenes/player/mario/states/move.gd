class_name MarioMoveState
extends PlayerState
## Walk/run and passive falling. Deliberate jumps use MarioJumpState.

@export var idle_state: PlayerState
@export var slide_state: PlayerState
@export var jump_state: PlayerState

var _previous_animation_speed: float = 1.0
var _falling: bool = false
var _defer_transformation_vertical := false


func defer_transformation_fall_step() -> void:
	_defer_transformation_vertical = true


func enter() -> void:
	_falling = false
	var mario := get_player() as Mario
	_previous_animation_speed = mario.animation_player.speed_scale
	mario.walk_animation.begin(mario.animation_player)


func exit() -> void:
	_defer_transformation_vertical = false
	if _falling:
		get_player().air_movement.end(get_player().motion_values)
		get_player().motion_values.remove_modifier(&"passive_fall")
		_falling = false
	get_player().animation_player.speed_scale = _previous_animation_speed


func process_physics(delta: float) -> BaseState:
	var player := get_player()
	var previous_speed := player.body.velocity.x
	var direction := prepare_horizontal_motion()
	var next := ground_transition(jump_state, self)
	if next != null:
		return continue_physics(next, delta)
	if not player.has_floor_support():
		return _process_falling(player, direction, delta)

	if player.slide_action.can_start(player.body, direction):
		return continue_physics(slide_state, delta)

	# Low-speed reversal finishes immediately instead of entering a visible skid.
	if player.slide_action.is_opposing(player.body, direction):
		player.body.velocity.x = 0.0

	player.horizontal_movement.apply(player.body, player.motion_values, direction, delta)
	player.face_direction(direction)
	player.body.velocity.y = 0.0
	player.move_body()
	if player.scripted_motion_step.is_valid():
		return null

	var mario := player as Mario
	if not mario.form_controller.is_crouched:
		mario.walk_animation.advance_pose(mario.animation_player, previous_speed)
	else:
		mario.walk_animation.pose_index = 0

	if is_zero_approx(direction) and is_zero_approx(player.body.velocity.x):
		return idle_state

	return null


func _process_falling(player: BasePlayer, direction: float, delta: float) -> BaseState:
	var previous_speed := player.body.velocity.x
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
	if _defer_transformation_vertical:
		# The NES runs one ground-control tick after transforming, then detects the fall.
		# Retain upward momentum; vertical integration starts on the next tick.
		_defer_transformation_vertical = false
		var vertical_speed := player.body.velocity.y
		player.body.velocity.y = 0.0
		player.move_body()
		player.body.velocity.y = vertical_speed
	else:
		player.move_body(true)
	if player.scripted_motion_step.is_valid():
		return null
	var mario := player as Mario
	if player.has_floor_support():
		mario.walk_animation.advance_pose(mario.animation_player, previous_speed)
		player.air_movement.end(player.motion_values)
		player.motion_values.remove_modifier(&"passive_fall")
		_falling = false
		if is_zero_approx(direction) and is_zero_approx(player.body.velocity.x):
			return idle_state
	else:
		mario.walk_animation.show_pose(mario.animation_player)
	return null
