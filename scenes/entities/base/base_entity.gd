class_name BaseEntity
extends Node2D

const SOUND_MIX = preload("res://assets/audio/sound_effect_mix.tres")
## Shared scene root for characters, pickups, and world objects.
## Specialized entities own their physics bodies as child nodes.

@export_group("Controller Input")
@export var controller_input_enabled: bool = false:
	set(value):
		controller_input_enabled = value
		_sync_controller_input()

@export_group("Presentation")
@export var visual_theme: AreaTheme
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer

@onready var state_machine: EntityStateMachine = $StateMachine

var _activity_geometry: Array[WeakRef] = []
var _controller_input_ready: bool = false
var _active_sound_effect: AudioStreamPlayer2D
var is_shutdown: bool = false
var gameplay_suspended: bool = false
var activity_suspended: bool = false
var _physics_suspended: bool = false
var _suspended_frames: Dictionary[int, Dictionary] = {}
var _paused_animations: Dictionary[int, Dictionary] = {}
var _suspended_physics: Dictionary[int, Dictionary] = {}


func _ready() -> void:
	_apply_visual_theme()
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
	_suspended_physics.clear()
	_suspended_frames.clear()
	_paused_animations.clear()
	_activity_geometry.clear()


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
	audio.volume_db = SOUND_MIX.volume_for(sound)
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
	if value:
		_suspend_frame_branch(self)
		for child in find_children("*", "Node", true, false):
			if not child is AnimationPlayer and not child is AnimatedSprite2D:
				continue
			_paused_animations[child.get_instance_id()] = {
				"node": weakref(child), "speed": child.speed_scale
			}
			child.speed_scale = 0.0
	else:
		for record: Dictionary in _suspended_frames.values():
			var node := (record.node as WeakRef).get_ref() as Node
			if is_instance_valid(node):
				node.set_process(record.enabled)
		_suspended_frames.clear()
		for record: Dictionary in _paused_animations.values():
			var node := (record.node as WeakRef).get_ref() as Node
			if is_instance_valid(node):
				node.set("speed_scale", record.speed)
		_paused_animations.clear()
	for synchronized in find_children("*", "SynchronizedAnimation", true, false):
		synchronized.set_activity_suspended(value)
	_sync_suspension()


func _sync_suspension() -> void:
	var suspended := gameplay_suspended or activity_suspended
	state_machine.gameplay_suspended = suspended
	if suspended != _physics_suspended:
		_physics_suspended = suspended
		if suspended:
			_suspend_physics_branch(self)
		else:
			for record: Dictionary in _suspended_physics.values():
				var node := (record.node as WeakRef).get_ref() as Node
				if is_instance_valid(node):
					node.set_physics_process(record.enabled)
			_suspended_physics.clear()
	_sync_controller_input()


func _suspend_frame_branch(node: Node) -> void:
	_suspended_frames[node.get_instance_id()] = {
		"node": weakref(node), "enabled": node.is_processing()
	}
	node.set_process(false)
	for child in node.get_children():
		_suspend_frame_branch(child)


## Call again after dynamically adding or replacing geometry.
func refresh_activity_geometry() -> void:
	_activity_geometry.clear()
	for child in find_children("*", "Node2D", true, false):
		if child is CollisionShape2D or child is Sprite2D:
			_activity_geometry.append(weakref(child))


## Includes moving child bodies rather than assuming the entity root moves.
func get_activity_rect() -> Rect2:
	var bounds := Rect2(global_position, Vector2.ZERO)
	var found := false
	for reference: WeakRef in _activity_geometry:
		var child := reference.get_ref() as Node2D
		if not is_instance_valid(child):
			continue
		var local_rect: Rect2
		if child is CollisionShape2D and child.shape != null:
			local_rect = child.shape.get_rect()
		elif child is Sprite2D and child.texture != null:
			local_rect = child.get_rect()
		else:
			continue
		var world_rect: Rect2 = child.global_transform * local_rect
		bounds = bounds.merge(world_rect) if found else world_rect
		found = true
	return bounds if found else Rect2(global_position - Vector2.ONE, Vector2(2, 2))


func _suspend_physics_branch(node: Node) -> void:
	_suspended_physics[node.get_instance_id()] = {
		"node": weakref(node), "enabled": node.is_physics_processing()
	}
	node.set_physics_process(false)
	for child in node.get_children():
		_suspend_physics_branch(child)


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
