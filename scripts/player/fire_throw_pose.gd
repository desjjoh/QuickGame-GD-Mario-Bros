class_name FireThrowPose
extends Node2D
## Composes the throw and Starman palette over the live motion pose.

const SHEET := preload("res://assets/player/mario + luigi (fire)/fire-throw.tres")
const FEET := Rect2(0, 24, 16, 8)

var _ticks_left := 0
var _base_color := Color.WHITE
var _keep_feet := false
var _walk_pose: Texture2D
var _feet_texture: Texture2D
var _palette: PlayerPalette

@onready var _base_sprite := get_parent() as Sprite2D


func _ready() -> void:
	_base_sprite.texture_changed.connect(queue_redraw)


func set_palette(palette: PlayerPalette) -> void:
	_palette = palette
	_refresh_overlay()


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
	_refresh_overlay()


func clear() -> void:
	if _feet_texture == null:
		return
	_ticks_left = 0
	_walk_pose = null
	_feet_texture = null
	_refresh_overlay()


func _refresh_overlay() -> void:
	if _feet_texture != null or _palette != null:
		if not visible:
			_base_color = _base_sprite.self_modulate
			_base_sprite.self_modulate.a = 0.0
			show()
		queue_redraw()
	elif visible:
		_base_sprite.self_modulate = _base_color
		hide()


func _apply_palette(texture: Texture2D) -> Texture2D:
	return _palette.remap_starman(texture) if _palette != null else texture


func _draw() -> void:
	if not visible:
		return
	var scale_x := -1.0 if _base_sprite.flip_h else 1.0
	if _feet_texture == null:
		var rect := _base_sprite.get_rect()
		draw_set_transform(rect.get_center(), 0.0, Vector2(scale_x, 1))
		draw_texture(_apply_palette(_base_sprite.texture), -rect.size / 2, _base_color)
		return
	var size := Vector2(16, 24 if _keep_feet else 32)
	var top_left := Vector2(-8, -16)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_x, 1))
	draw_texture_rect_region(
		_apply_palette(SHEET), Rect2(top_left, size), Rect2(Vector2.ZERO, size), _base_color
	)
	if _keep_feet:
		draw_texture_rect_region(
			_apply_palette(_feet_texture), Rect2(-8, 8, 16, 8), FEET, _base_color
		)
