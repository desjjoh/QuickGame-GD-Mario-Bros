class_name LevelCamera
extends Camera2D
## Called after player movement and before the level's screen-edge clamp.

@export var follow_enabled: bool = true
@export var world_left: float = -128.0
@export var world_right: float = 768.0
@export var scroll_start: float = 80.0
@export var full_speed_start: float = 112.0
## Mario's body origin is 8 pixels right of the NES sprite's top-left origin.
@export var target_origin_offset: float = 8.0

var _target_x: float
var _has_target: bool = false


func reset_target(target: CharacterBody2D) -> void:
	_target_x = target.global_position.x
	_has_target = true
	reset_physics_interpolation()
	force_update_scroll()


func follow_target(target: CharacterBody2D) -> void:
	if not _has_target:
		reset_target(target)
	var current_x := target.global_position.x
	var advance := current_x - _target_x
	_target_x = current_x
	if not follow_enabled or advance <= 0.0:
		return
	var width := get_viewport_rect().size.x / zoom.x
	# Keep interpolated presentation coordinates out of physics feedback.
	var left := global_position.x - width / 2.0
	var screen_x := current_x - target_origin_offset - left
	if screen_x < scroll_start:
		return
	# Keep the reference's early catch-up zone without alternating integer
	# steps against a continuously moving player.
	if screen_x < full_speed_start:
		advance *= 0.5
	var next_left := clampf(left + advance, world_left, maxf(world_left, world_right - width))
	global_position.x = next_left + width / 2.0
	force_update_scroll()


func snap_to_arrival(target: CharacterBody2D) -> void:
	# Arrival at another endpoint explicitly resets right-only camera history.
	if follow_enabled:
		var width := get_viewport_rect().size.x / zoom.x
		var left := clampf(target.global_position.x - target_origin_offset - full_speed_start,
			world_left, maxf(world_left, world_right - width))
		global_position.x = left + width / 2.0
	reset_target(target)
