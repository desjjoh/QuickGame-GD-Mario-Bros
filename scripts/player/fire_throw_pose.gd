class_name FireThrowPose
extends Node2D
## Draws the throw over the motion pose without taking over the AnimationPlayer.

const SHEET := preload("res://assets/player/mario + luigi (fire)/shoot.png")
const FEET := Rect2(0, 24, 16, 8)

var _ticks_left := 0
var _base_color := Color.WHITE
var _keep_feet := false
var _walk_pose: Texture2D
var _feet_texture: Texture2D

@onready var _base_sprite := get_parent() as Sprite2D


func update_pose(timer_reload: int, walking: bool, keep_feet: bool) -> void:
	if timer_reload > 0:
		_ticks_left = timer_reload
		_walk_pose = _base_sprite.texture if walking else null
	elif _ticks_left == 0 or (walking and _ticks_left == 1):
		clear()
		return
	# Walking reloads its animation timer at zero, ending the throw one tick early.
	_ticks_left -= 1
	if not walking:
		_walk_pose = null
	_keep_feet = keep_feet
	_feet_texture = _walk_pose if _walk_pose != null else _base_sprite.texture
	if not visible:
		_base_color = _base_sprite.self_modulate
		_base_sprite.self_modulate.a = 0.0
		show()
	queue_redraw()


func clear() -> void:
	if not visible:
		return
	_ticks_left = 0
	_walk_pose = null
	_feet_texture = null
	_base_sprite.self_modulate = _base_color
	hide()


func _draw() -> void:
	if not visible:
		return
	var size := Vector2(16, 24 if _keep_feet else 32)
	var top_left := Vector2(-8, -16)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1 if _base_sprite.flip_h else 1, 1))
	draw_texture_rect_region(SHEET, Rect2(top_left, size), Rect2(Vector2.ZERO, size), _base_color)
	if _keep_feet:
		draw_texture_rect_region(_feet_texture, Rect2(-8, 8, 16, 8), FEET, _base_color)
