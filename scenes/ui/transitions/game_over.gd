extends Control

@export var sound: AudioStream
@export var fallback_timeout: float = 10.0
@onready var audio: AudioStreamPlayer = $Audio
var _elapsed: float = 0.0
var _complete: bool = false


func _ready() -> void:
	if sound == null:
		_complete = true
		set_physics_process(false)
		return
	audio.stream = SoundHandler.one_shot_copy(sound)
	audio.finished.connect(_on_audio_finished)
	audio.play()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= maxf(fallback_timeout, sound.get_length() + 1.0):
		audio.stop()
		_on_audio_finished()


func _on_audio_finished() -> void:
	_complete = true
	set_physics_process(false)


func is_presentation_complete() -> bool:
	return _complete


func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()
