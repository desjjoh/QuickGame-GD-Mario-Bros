class_name MarioSlideState
extends PlayerState
## Faces opposite momentum while the Slide action brakes the physical body.

@export var move_state: PlayerState
@export var idle_state: PlayerState
@export var jump_state: PlayerState
@export var slide_sound: AudioStreamMP3
## SMB2J's skid sound runs for six frames before accepting another request.
@export var skid_repeat_interval: float = 6.0 / 60.0

var _slide_audio: AudioStreamPlayer2D
var _skid_stream: AudioStreamMP3
var _skid_elapsed: float = 0.0


func enter() -> void:
	var player := get_player()
	player.slide_action.begin(player.motion_values)
	player.face_direction(get_movement_axis().x)
	if slide_sound != null and player.body.is_on_floor() and not is_zero_approx(player.body.velocity.x):
		# Retrigger short bursts rather than looping the full recording.
		_skid_stream = slide_sound.duplicate() as AudioStreamMP3
		_skid_stream.loop = false
		_slide_audio = player.play_sound_effect(_skid_stream)
	_skid_elapsed = 0.0


func exit() -> void:
	_stop_slide_sound()
	var player := get_player()
	player.slide_action.end(player.motion_values)


func _stop_slide_sound() -> void:
	if is_instance_valid(_slide_audio):
		_slide_audio.stop()
		_slide_audio.queue_free()
	_slide_audio = null
	_skid_stream = null
	_skid_elapsed = 0.0


func process_physics(delta: float) -> BaseState:
	var player := get_player()
	var direction := prepare_horizontal_motion()
	var next := ground_transition(jump_state, move_state)
	if next == jump_state and next != null:
		return continue_jump_physics(next, delta)
	if next != null:
		return next
	if _skid_stream != null:
		_skid_elapsed += delta
		if _skid_elapsed >= maxf(skid_repeat_interval, 0.001):
			_skid_elapsed = fmod(_skid_elapsed, maxf(skid_repeat_interval, 0.001))
			_slide_audio = player.play_sound_effect(_skid_stream)
	# Neutral input preserves the skid and facing until braking completes.
	# Only actively resuming the momentum direction cancels the reversal.
	if not is_zero_approx(direction) and not player.slide_action.is_opposing(player.body, direction):
		return move_state
	player.face_direction(direction)
	var stopped := player.slide_action.apply(player.motion_values, delta)
	player.gravity_component.apply(player.motion_values, delta)
	player.move_body()
	if not player.body.is_on_floor():
		_stop_slide_sound()
	if stopped or is_zero_approx(player.body.velocity.x):
		return move_state if not is_zero_approx(direction) else idle_state
	return null

