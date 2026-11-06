class_name PlayerPipeEnterState
extends PlayerTransportState

## Directional pipe entry and emergence; normal movement and collisions are suspended.

signal descent_finished

@export var entry_sound_cue: StringName
@export var entry_speed: float = 60.0
@export var entry_duration: float = 48.0 / 60.0
## Normal side-pipe timer after the sprite's left edge reaches the next grid boundary.
@export var side_entry_delay: float = 52.0 / 60.0
@export var walk_animation_name: StringName = &""
@export var walk_cadence: WalkAnimationComponent

var _travel_distance: float = 0.0
var _walking: bool = false
var _animation_speed: float = 1.0
var _origin_flip_h: bool = false
var _direction: Vector2 = Vector2.DOWN
var _emerging: bool = false
var _opening: Vector2
var _origin: Vector2
var _elapsed: float = 0.0
var _collision_layer: int
var _collision_mask: int
var _sprite_visible: bool = true
var _hidden_depth: float = 17.0
var _duration: float = 0.8
var _finished: bool = false
var _committed: bool = false


func _ready() -> void:
	if enter_sound_effect == null:
		enter_sound_effect = SoundHandler.get_sound(entry_sound_cue)
		return
	# One-shot runtime copy; preserve the supplied asset's import settings.
	if enter_sound_effect is AudioStreamWAV:
		enter_sound_effect = SoundHandler.one_shot_copy(enter_sound_effect)


func configure(
	opening: Vector2,
	direction: Vector2 = Vector2.DOWN,
	emerging: bool = false,
	distance: float = 0.0
) -> void:
	_opening = opening
	_direction = direction
	_emerging = emerging
	_travel_distance = distance


func activate() -> void:
	# Entry and emergence share a state, but only entry plays its sound.
	var sound := enter_sound_effect
	if _emerging:
		enter_sound_effect = null
	super()
	enter_sound_effect = sound


func enter() -> void:
	var player := get_player()
	_origin = player.body.global_position
	_elapsed = 0.0
	_finished = false
	_committed = false
	_walking = false
	if player.animation_player != null:
		_animation_speed = player.animation_player.speed_scale
	if player.sprite != null:
		_origin_flip_h = player.sprite.flip_h
	if _direction.x != 0.0 or _emerging:
		player.face_direction(_direction.x if _direction.x != 0.0 else 1.0)
	if not _emerging and _direction.x == 0.0:
		# The mouth validates alignment; vertical entry must not recenter the body.
		_opening.x = _origin.x
	_collision_layer = player.body.collision_layer
	_collision_mask = player.body.collision_mask
	player.body.collision_layer = 0
	player.body.collision_mask = 0
	player.body.velocity = Vector2.ZERO
	player.body.global_position = _opening
	player.body.reset_physics_interpolation()
	if player.sprite != null:
		_sprite_visible = player.sprite.visible
		_hidden_depth = maxf(
			1.0, -(player.sprite.position.y + player.sprite.get_rect().position.y) + 1.0
		)
	if _direction.x != 0.0:
		# Body origin is sprite center; a left-edge grid boundary is center +8.
		_hidden_depth = 14.0
		_duration = _hidden_depth / 30.0 + maxf(side_entry_delay, 0.0)
	else:
		_duration = maxf(maxf(entry_duration, 0.01), _hidden_depth / maxf(entry_speed, 1.0))
	if _emerging:
		_travel_distance = maxf(_travel_distance, _hidden_depth)
		_duration = _travel_distance / _speed()
		player.body.global_position = _opening - _direction * _travel_distance
		if player.sprite != null:
			player.sprite.hide()
		player.body.reset_physics_interpolation()
	if _direction.x != 0.0 and walk_animation_name != &"":
		_walking = true
		_play_animation(walk_animation_name)
		if walk_cadence != null:
			walk_cadence.apply(player.animation_player, _speed())
		if player.animation_player != null:
			player.animation_player.advance(0.0)


func _speed() -> float:
	return 30.0 if _direction.x != 0.0 else maxf(entry_speed, 1.0)


func process_physics(delta: float) -> BaseState:
	if _finished:
		return null
	_elapsed = minf(_duration, _elapsed + delta)
	# Avoid an extra locked tick from accumulated floating-point roundoff.
	if _duration - _elapsed <= 0.000001:
		_elapsed = _duration
	var depth := _speed() * _elapsed
	if _emerging:
		depth = minf(_travel_distance, depth)
	elif _direction.x != 0.0:
		depth = minf(_hidden_depth, depth)
		if _walking and depth >= _hidden_depth:
			_walking = false
			apply_presentation()
	var player := get_player()
	player.body.global_position = (
		_opening + _direction * (depth - _travel_distance if _emerging else depth)
	)
	player.body.velocity = Vector2.ZERO
	if player.sprite != null:
		player.sprite.visible = (
			_sprite_visible
			and (_travel_distance - depth < _hidden_depth if _emerging else depth < _hidden_depth)
		)
	if _elapsed >= _duration:
		_finished = true
		travel_finished.emit()
		descent_finished.emit()
	return null


func commit_transfer() -> void:
	_committed = true


func exit() -> void:
	var player := get_player()
	if player.animation_player != null:
		player.animation_player.stop(true)
		player.animation_player.speed_scale = _animation_speed
	player.body.collision_layer = _collision_layer
	player.body.collision_mask = _collision_mask
	if player.sprite != null:
		player.sprite.visible = _sprite_visible
	if not _committed:
		if player.sprite != null:
			player.sprite.flip_h = _origin_flip_h
		player.body.global_position = _origin
		player.body.velocity = Vector2.ZERO
		player.body.reset_physics_interpolation()
		if is_instance_valid(_enter_audio):
			_enter_audio.stop()
			_enter_audio.queue_free()
