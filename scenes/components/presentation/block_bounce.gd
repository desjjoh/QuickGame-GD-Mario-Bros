class_name BlockBounce
extends Node
## Visual-only bounce. The solid body stays in its grid cell.

const DRAW_ORDER := preload("res://scenes/components/presentation/draw_order.gd")

@export var initial_speed: float = -120.0
@export var gravity: float = 1125.0

var _sprite: Sprite2D
var _origin: Vector2
var _original_z_index: int
var _original_z_as_relative: bool
var _speed: float
var _offset: float = 0.0
var _running: bool = false


func begin(target: Sprite2D) -> void:
	reset()
	_sprite = target
	_origin = target.position
	_original_z_index = target.z_index
	_original_z_as_relative = target.z_as_relative
	DRAW_ORDER.apply(target, DRAW_ORDER.BOUNCING_BLOCK)
	_speed = initial_speed
	_offset = 0.0
	_running = true


func advance(delta: float) -> void:
	if not _running:
		return
	_offset += _speed * delta
	_speed += gravity * delta
	if _offset >= 0.0 and _speed > 0.0:
		reset()
	else:
		_sprite.position = _origin + Vector2(0.0, _offset)


func reset() -> void:
	if _running and is_instance_valid(_sprite):
		_sprite.position = _origin
		_sprite.z_index = _original_z_index
		_sprite.z_as_relative = _original_z_as_relative
	_running = false


func is_running() -> bool:
	return _running
