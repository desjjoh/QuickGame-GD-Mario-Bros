class_name BaseEntity
extends Node2D
## Shared scene root for characters, pickups, and world objects.
## Specialized entities own their physics bodies as child nodes.

@export_group("Presentation")
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer

@onready var state_machine: EntityStateMachine = $StateMachine

var _active_sound_effect: AudioStreamPlayer2D
var is_shutdown: bool = false


func _ready() -> void:
	if not state_machine.initialize(self):
		return
	if animation_player != null:
		animation_player.animation_finished.connect(state_machine.on_animation_finished)
	state_machine.start()
	ControllerHandler.input_received.connect(state_machine.process_input)


func _process(delta: float) -> void:
	if not is_shutdown:
		state_machine.update(delta)


func _physics_process(delta: float) -> void:
	if not is_shutdown:
		state_machine.process_physics(delta)


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	if is_shutdown:
		return
	is_shutdown = true
	set_process(false)
	set_physics_process(false)
	if not is_instance_valid(state_machine):
		return
	if ControllerHandler.input_received.is_connected(state_machine.process_input):
		ControllerHandler.input_received.disconnect(state_machine.process_input)
	if is_instance_valid(animation_player):
		if animation_player.animation_finished.is_connected(state_machine.on_animation_finished):
			animation_player.animation_finished.disconnect(state_machine.on_animation_finished)
	state_machine.shutdown()
	if is_instance_valid(animation_player):
		animation_player.stop()
	if is_instance_valid(_active_sound_effect):
		_active_sound_effect.stop()
		_active_sound_effect.queue_free()
	_active_sound_effect = null


func get_effects_parent() -> Node2D:
	return self


func play_sound_effect(sound: AudioStream) -> AudioStreamPlayer2D:
	if sound == null or is_shutdown:
		return null
	if is_instance_valid(_active_sound_effect):
		_active_sound_effect.stop()
		_active_sound_effect.queue_free()
	var audio := AudioStreamPlayer2D.new()
	_active_sound_effect = audio
	audio.stream = sound
	get_effects_parent().add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
	return audio
