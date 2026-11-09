class_name EnemyDefeatedState
extends EntityState

@export var duration := 0.5
@export var launch_speed := 0.0
@export var horizontal_speed := 0.0

var launch_direction := 1.0
var fireball_launch := false
var star_launch := false

var _elapsed := 0.0
var _velocity := Vector2.ZERO
var _launch_hit_tick := -1
var _speed_units := 0
var _position_fraction := 0
var _sprite_anchor := Vector2.ZERO
var _star_pose := preload("res://scenes/components/presentation/block_launch_presentation.gd").new()


func enter() -> void:
	_elapsed = 0.0
	_velocity = Vector2(horizontal_speed * launch_direction, launch_speed)
	(entity as BaseEnemy).body.velocity = Vector2.ZERO
	if star_launch:
		_star_pose.capture(entity.sprite)
	else:
		_apply_launch_pose()
	if fireball_launch or star_launch:
		_launch_hit_tick = Engine.get_physics_frames()
		_speed_units = roundi(launch_speed / 60.0 * 256.0)
		_position_fraction = 0
		_sprite_anchor = entity.sprite.position
		(entity as BaseEnemy).body.position.y -= 2.0
		_advance_fractional_launch()
		if star_launch:
			_star_pose.hold_after_motion(entity.sprite, (entity as BaseEnemy).body)
		entity.reset_physics_interpolation()


func _apply_launch_pose() -> void:
	entity.sprite.flip_v = launch_speed != 0.0


func process_physics(delta: float) -> BaseState:
	if fireball_launch or star_launch:
		if Engine.get_physics_frames() != _launch_hit_tick:
			var reveal := _star_pose.is_holding()
			if reveal:
				_apply_launch_pose()
				_sprite_anchor = entity.sprite.position
			_advance_fractional_launch()
			if reveal:
				_star_pose.reveal(entity.sprite, entity.sprite.position)
		return null
	_elapsed += delta
	if launch_speed != 0.0:
		var body := (entity as BaseEnemy).body
		body.position += _velocity * delta
		_velocity.y = minf(_velocity.y + 61.0 / 256.0 * 60.0 * 60.0 * delta, 180.0)
		return null
	if _elapsed >= duration:
		entity.queue_free()
	return null


func _advance_fractional_launch() -> void:
	var body := (entity as BaseEnemy).body
	var step := _speed_units + _position_fraction
	var motion := Vector2(_velocity.x / 60.0, step >> 8)
	_position_fraction = step & 0xff
	_speed_units += 61
	if _speed_units >= 3 * 256 + 128:
		_speed_units = 3 * 256
	body.position += motion
	# The ROM draws the corrected pose before advancing the defeated body.
	entity.sprite.position = _sprite_anchor - motion


func exit() -> void:
	if _star_pose.is_holding():
		_star_pose.cancel(entity.sprite)
	elif fireball_launch or star_launch:
		entity.sprite.position = _sprite_anchor
