class_name PlayerClimbState
extends PlayerState
## Reusable controlled climbing state; concrete players own its scene node.

@export var move_state: PlayerState
@export var upward_animation_speed: float = 1.0
@export var downward_animation_speed: float = 2.0

var _animation_speed: float = 1.0


func enter() -> void:
	var player := get_player()
	_animation_speed = (
		player.animation_player.speed_scale if player.animation_player != null else 1.0
	)
	if player.animation_player != null:
		player.animation_player.seek(0.0, true)
		player.animation_player.pause()
	player.climbing.notify_attached(player)


func process_physics(delta: float) -> BaseState:
	if not advance_climb(get_movement_axis(), delta):
		# step exits before integrating; Move consumes this tick once on release.
		return continue_physics(move_state, delta)
	return null


func advance_climb(axis: Vector2, delta: float, vertical_step: float = NAN) -> bool:
	var player := get_player()
	var before := player.body.global_position
	if not player.climbing.step(player, axis, delta, vertical_step):
		return false
	if player.animation_player != null and animation_name != &"":
		if not is_equal_approx(before.y, player.body.global_position.y):
			player.animation_player.speed_scale = (
				upward_animation_speed if axis.y < 0.0 else downward_animation_speed
			)
			player.animation_player.play(animation_name)
		else:
			# Neutral/blocked climbing always uses its initial idle pose.
			hold_pose()
	return true


func hold_pose() -> void:
	var animation := get_player().animation_player
	if animation != null:
		animation.seek(0.0, true)
		animation.pause()


func exit() -> void:
	var player := get_player()
	if player.animation_player != null:
		player.animation_player.stop(true)
		player.animation_player.speed_scale = _animation_speed
	player.climbing.detach(player)
