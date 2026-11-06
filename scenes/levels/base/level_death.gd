class_name LevelDeath
extends Node
## Runs an accepted death until the presentation and jingle have finished.

signal presentation_finished(victim: BasePlayer)
signal finished

var _victim: BasePlayer
var _audio: AudioStreamPlayer
var _active := false
var _presentation_done := false
var _audio_done := false
var _has_sound := false
var _elapsed := 0.0
var _fallback_delay := 0.0
var _audio_limit := 0.0
var _presentation_limit := 0.0


func begin(
	world: Node,
	victim: BasePlayer,
	present: bool,
	sound: AudioStream,
	fallback_delay: float,
	presentation_timeout: float
) -> void:
	_active = true
	_victim = victim
	_presentation_done = false
	_has_sound = sound != null
	_audio_done = not _has_sound
	_elapsed = 0.0
	_fallback_delay = fallback_delay
	_audio_limit = maxf(fallback_delay, sound.get_length() + 1.0) if _has_sound else fallback_delay
	_presentation_limit = maxf(presentation_timeout, _audio_limit)
	# Gameplay callbacks stop while cosmetic animations keep advancing.
	for entity in world.find_children("*", "BaseEntity", true, false):
		if entity != victim:
			(entity as BaseEntity).set_gameplay_suspended(true)
	if _has_sound:
		_audio = AudioStreamPlayer.new()
		_audio.stream = SoundHandler.one_shot_copy(sound)
		add_child(_audio)
		_audio.finished.connect(_on_audio_finished)
		_audio.play()
	victim.death_presentation_finished.connect(_finish_presentation, CONNECT_ONE_SHOT)
	victim.begin_death(present)


func advance(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if _elapsed >= _presentation_limit or not is_instance_valid(_victim):
		_finish_presentation()
	if (
		_active
		and _presentation_done
		and (_audio_done or _elapsed >= _audio_limit)
		and (_has_sound or _elapsed >= _fallback_delay)
	):
		_active = false
		finished.emit()


func cancel() -> void:
	_active = false
	_disconnect_victim()
	_victim = null
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.queue_free()
		_audio = null


func _finish_presentation() -> void:
	if not _active or _presentation_done:
		return
	_presentation_done = true
	_disconnect_victim()
	var victim := _victim if is_instance_valid(_victim) else null
	_victim = null
	presentation_finished.emit(victim)


func _disconnect_victim() -> void:
	if (
		is_instance_valid(_victim)
		and _victim.death_presentation_finished.is_connected(_finish_presentation)
	):
		_victim.death_presentation_finished.disconnect(_finish_presentation)


func _on_audio_finished() -> void:
	_audio_done = true


func _exit_tree() -> void:
	cancel()
