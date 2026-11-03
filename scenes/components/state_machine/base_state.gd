class_name BaseState
extends Node
## Override these hooks instead of Godot's automatic processing callbacks.
## Return another registered state to transition, or null to remain here.

signal entered
signal exited

@export_group("Enter Presentation")
@export var animation_name: StringName = &""
@export var synchronized_animation: SynchronizedAnimation
## Null preserves the current texture. Static poses can be assigned per state.
@export var sprite_texture: Texture2D
@export var stop_animation_on_enter: bool = false
## -1 leaves the current frame unchanged; 0 or higher selects a static pose.
@export var sprite_frame: int = -1
@export var sprite_visible: bool = true
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var mirror_sprite_offset: bool = true
@export var sprite_tint: Color = Color.WHITE
@export var enter_sound_effect: AudioStream

@export_group("Exit Presentation")
@export var exit_animation_name: StringName = &""
@export var exit_sound_effect: AudioStream

@export_group("Processing")
@export var frame_updates_enabled: bool = true
@export var physics_updates_enabled: bool = true
@export var input_enabled: bool = true

var _enter_audio: AudioStreamPlayer2D = null

var entity: BaseEntity
var state_machine: EntityStateMachine


func activate() -> void:
	apply_presentation()
	if synchronized_animation != null:
		synchronized_animation.set_enabled(true)
	_enter_audio = entity.play_sound_effect(enter_sound_effect)
	enter()
	entered.emit()


func deactivate(play_exit_presentation: bool = true) -> void:
	if synchronized_animation != null:
		synchronized_animation.set_enabled(false)
	exit()
	if play_exit_presentation and not entity.is_shutdown:
		_play_animation(exit_animation_name)
		entity.play_sound_effect(exit_sound_effect)
	exited.emit()


func apply_presentation() -> void:
	if stop_animation_on_enter and entity.animation_player != null:
		entity.animation_player.stop(true)
	if entity.sprite != null:
		if sprite_texture != null:
			entity.sprite.texture = entity.resolve_texture(sprite_texture)
		if sprite_frame >= 0 and sprite_frame < entity.sprite.hframes * entity.sprite.vframes:
			entity.sprite.frame = sprite_frame
		entity.sprite.visible = sprite_visible
		entity.sprite.modulate = sprite_tint
		apply_sprite_offset()
	_play_animation(animation_name)


func apply_sprite_offset() -> void:
	if entity.sprite == null:
		return
	var offset := sprite_offset
	if mirror_sprite_offset and entity.sprite.flip_h:
		offset.x = -offset.x
	entity.sprite.offset = offset


func _play_animation(animation: StringName) -> void:
	if animation == &"":
		return
	if entity.animation_player == null:
		push_warning("State %s requests an animation but has no AnimationPlayer." % name)
	elif not entity.animation_player.has_animation(animation):
		push_warning("Animation '%s' does not exist for state %s." % [animation, name])
	else:
		entity.animation_player.play(animation)


func enter() -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> BaseState:
	return null


func process_physics(_delta: float) -> BaseState:
	return null


func process_input(_event: InputEvent) -> BaseState:
	return null


func animation_finished(_animation: StringName) -> BaseState:
	return null
