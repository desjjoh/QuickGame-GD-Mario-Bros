class_name PlayerPipeEnterState
extends PlayerState
## Controlled downward entry. No normal movement, gravity, or collision response.

signal descent_finished

@export var entry_speed: float = 60.0
@export var entry_duration: float = 48.0 / 60.0

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
	# One-shot runtime copy; preserve the supplied asset's import settings.
	if enter_sound_effect is AudioStreamWAV:
		enter_sound_effect = enter_sound_effect.duplicate()
		(enter_sound_effect as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED


func configure(opening: Vector2) -> void:
	_opening = opening


func enter() -> void:
	var player := get_player()
	_origin = player.body.global_position
	_elapsed = 0.0
	_finished = false
	_committed = false
	_collision_layer = player.body.collision_layer
	_collision_mask = player.body.collision_mask
	player.body.collision_layer = 0
	player.body.collision_mask = 0
	player.body.velocity = Vector2.ZERO
	player.body.global_position = _opening
	player.body.reset_physics_interpolation()
	if player.sprite != null:
		_sprite_visible = player.sprite.visible
		_hidden_depth = maxf(1.0, -(player.sprite.position.y + player.sprite.get_rect().position.y) + 1.0)
	_duration = maxf(maxf(entry_duration, 0.01), _hidden_depth / maxf(entry_speed, 1.0))


func process_physics(delta: float) -> BaseState:
	if _finished:
		return null
	_elapsed = minf(_duration, _elapsed + delta)
	var depth := maxf(entry_speed, 1.0) * _elapsed
	var player := get_player()
	player.body.global_position = _opening + Vector2(0, depth)
	player.body.velocity = Vector2.ZERO
	if player.sprite != null and depth >= _hidden_depth:
		player.sprite.hide()
	if _elapsed >= _duration:
		_finished = true
		descent_finished.emit()
	return null


func commit_transfer() -> void:
	_committed = true


func exit() -> void:
	var player := get_player()
	player.body.collision_layer = _collision_layer
	player.body.collision_mask = _collision_mask
	if player.sprite != null:
		player.sprite.visible = _sprite_visible
	if not _committed:
		player.body.global_position = _origin
		player.body.velocity = Vector2.ZERO
		player.body.reset_physics_interpolation()
		if is_instance_valid(_enter_audio):
			_enter_audio.stop()
			_enter_audio.queue_free()
