class_name BaseEntity
extends Node2D
## Shared scene root for characters, pickups, and world objects.
## Specialized entities own their physics bodies as child nodes.

@export_group("Presentation")
@export var visual_theme: AreaTheme
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer

@onready var state_machine: EntityStateMachine = $StateMachine

var _active_sound_effect: AudioStreamPlayer2D
var is_shutdown: bool = false


func _ready() -> void:
	_apply_visual_theme()
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


func resolve_texture(texture: Texture2D) -> Texture2D:
	return visual_theme.resolve_texture(texture) if visual_theme != null else texture


func _apply_visual_theme() -> void:
	if visual_theme == null:
		return
	for child in find_children("*", "Sprite2D", true, false):
		var child_sprite := child as Sprite2D
		child_sprite.texture = resolve_texture(child_sprite.texture)
	if animation_player == null or visual_theme.texture_overrides.is_empty():
		return
	# Clone animation containers only; never alter another area's shared assets.
	for library_name in animation_player.get_animation_library_list():
		var original := animation_player.get_animation_library(library_name)
		var library := AnimationLibrary.new()
		for animation_name in original.get_animation_list():
			var animation := original.get_animation(animation_name).duplicate() as Animation
			for track in range(animation.get_track_count()):
				if animation.track_get_type(track) != Animation.TYPE_VALUE:
					continue
				for key in range(animation.track_get_key_count(track)):
					var value = animation.track_get_key_value(track, key)
					if value is Texture2D:
						animation.track_set_key_value(track, key, resolve_texture(value))
			library.add_animation(animation_name, animation)
		animation_player.remove_animation_library(library_name)
		animation_player.add_animation_library(library_name, library)
