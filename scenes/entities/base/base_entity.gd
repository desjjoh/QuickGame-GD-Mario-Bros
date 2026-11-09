class_name BaseEntity
extends Node2D

const ACTIVITY = preload("res://scenes/entities/base/entity_activity.gd")
const THEME_APPLIER = preload("res://scripts/themes/entity_theme_applier.gd")

## Shared scene root for characters, pickups, and world objects.
## Specialized entities own their physics bodies as child nodes.

@export_group("Controller Input")
@export var controller_input_enabled: bool = false:
	set(value):
		controller_input_enabled = value
		_sync_controller_input()

@export_group("Progress Persistence")
## Preserve the entity's outcome across area reload and death restart.
@export var persist_progress: bool = true

@export_group("Presentation")
@export var visual_theme: AreaTheme
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer

@onready var state_machine: EntityStateMachine = $StateMachine

var _activity := ACTIVITY.new()
var _controller_input_ready: bool = false
var _active_sound_effect: AudioStreamPlayer
var is_shutdown: bool = false
var gameplay_suspended: bool = false
var activity_suspended: bool = false


func _ready() -> void:
	THEME_APPLIER.apply(self)
	if not state_machine.initialize(self):
		return
	_controller_input_ready = true
	if animation_player != null:
		animation_player.animation_finished.connect(state_machine.on_animation_finished)
	state_machine.start()
	_sync_controller_input()
	refresh_activity_geometry()
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_method("register_activity_entity"):
			ancestor.register_activity_entity(self)
			break
		ancestor = ancestor.get_parent()


func _process(delta: float) -> void:
	if not is_shutdown:
		state_machine.update(delta)


func _physics_process(delta: float) -> void:
	if not is_shutdown:
		state_machine.process_physics(delta)


func _exit_tree() -> void:
	shutdown()


## Shuts down parent entities before their descendants, including nested actors.
static func shutdown_descendants(root: Node) -> void:
	for child in root.get_children():
		if child is BaseEntity:
			child.shutdown()
		shutdown_descendants(child)


func shutdown() -> void:
	if is_shutdown:
		return
	is_shutdown = true
	_controller_input_ready = false
	for synchronized in find_children("*", "SynchronizedAnimation", true, false):
		synchronized.set_enabled(false)
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
	_activity.clear()


func get_effects_parent() -> Node2D:
	return self


func play_sound_effect(sound: AudioStream) -> AudioStreamPlayer:
	if sound == null or is_shutdown:
		return null
	if is_instance_valid(_active_sound_effect):
		_active_sound_effect.stop()
		_active_sound_effect.queue_free()
	var audio := AudioStreamPlayer.new()
	audio.bus = SoundHandler.NES_MIX_BUS
	_active_sound_effect = audio
	audio.stream = sound
	get_effects_parent().add_child(audio)
	SoundHandler.register_action_voice(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
	return audio


func resolve_texture(texture: Texture2D) -> Texture2D:
	return visual_theme.resolve_texture(texture) if visual_theme != null else texture


func capture_area_state() -> Dictionary:
	return {}  # Specialized entities opt in to logical progress persistence.


func restore_area_state(_data: Dictionary) -> void:
	pass  # Called before entering the tree, before the initial state starts.


func set_gameplay_suspended(value: bool) -> void:
	if is_shutdown or gameplay_suspended == value:
		return
	gameplay_suspended = value
	_sync_suspension()


func set_activity_suspended(value: bool) -> void:
	if is_shutdown or activity_suspended == value:
		return
	activity_suspended = value
	_activity.apply_activity_suspension(self, value)
	_sync_suspension()


func _sync_suspension() -> void:
	var suspended := gameplay_suspended or activity_suspended
	state_machine.gameplay_suspended = suspended
	_activity.sync_physics(self, suspended)
	_sync_controller_input()


## Call again after dynamically adding or replacing geometry.
func refresh_activity_geometry() -> void:
	_activity.refresh_geometry(self)


## Includes moving child bodies rather than assuming the entity root moves.
func get_activity_rect() -> Rect2:
	return _activity.get_rect(self)


func can_read_controller_input() -> bool:
	return (
		_controller_input_ready
		and controller_input_enabled
		and not is_shutdown
		and not gameplay_suspended
		and not activity_suspended
	)


func _sync_controller_input() -> void:
	if not is_instance_valid(state_machine):
		return
	var callback := state_machine.process_input
	var connected := ControllerHandler.input_received.is_connected(callback)
	if can_read_controller_input():
		if not connected:
			ControllerHandler.input_received.connect(callback)
	elif connected:
		ControllerHandler.input_received.disconnect(callback)
