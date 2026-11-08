class_name MarioDeadState
extends PlayerState
## Death-only motion; BaseLevel owns life loss, audio, cleanup and restart.

@export_range(0, 120, 1) var hold_frames: int = 16
@export var launch_velocity: float = -240.0
@export var death_gravity: float = 562.5
@export var maximum_fall_speed: float = 240.0

var _hold_remaining: int = 0
var _launched: bool = false


func enter() -> void:
	_hold_remaining = hold_frames
	_launched = false
	get_player().body.velocity = Vector2.ZERO


func process_physics(delta: float) -> BaseState:
	var player := get_player()
	if not player.is_dead or player.is_shutdown:
		return null
	if _hold_remaining > 0:
		_hold_remaining -= 1
		return null
	if not _launched:
		player.body.velocity.y = launch_velocity
		_launched = true
	player.body.velocity.x = 0.0
	# Collision is disabled by begin_death. Bypass normal jump, corner and
	# ceiling logic; integrate position before gravity, as the reference does.
	player.body.move_and_slide()
	player.body.velocity.y = minf(
		player.body.velocity.y + death_gravity * delta, maximum_fall_speed
	)
	var camera := get_viewport().get_camera_2d()
	if camera == null or player.body.velocity.y <= 0.0:
		return null
	var bottom := (
		camera.global_position.y + get_viewport().get_visible_rect().size.y / camera.zoom.y / 2.0
	)
	# The visual baseline is one pixel below the collision envelope, so use
	# the actual sprite top to avoid removing its final visible row early.
	var sprite_top := player.sprite.to_global(player.sprite.get_rect().position).y
	if sprite_top > bottom:
		player.finish_death()
	return null
