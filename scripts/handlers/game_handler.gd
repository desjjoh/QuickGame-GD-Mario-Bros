extends Node
## Global game ownership and in-memory session data. No disk persistence yet.

signal level_changed(level: BaseLevel)
signal session_value_changed(key: StringName, value: Variant)

var current_game: Node
var current_level: BaseLevel
var current_player: BasePlayer
var _level_container: Node2D
var _session: Dictionary[StringName, Variant] = {}
var _area_progress: Dictionary = {}
var _loading: bool = false
var animation_clock := CosmeticAnimationClock.new()
# Global world-progress policy; session counters/lives are unaffected.
var reset_progress_on_death: bool = false
var _current_level_scene: PackedScene


func _ready() -> void:
	animation_clock.name = "AnimationClock"
	add_child(animation_clock)


func attach_game(game: Node, level_container: Node2D) -> void:
	current_game = game
	_level_container = level_container


func detach_game(game: Node) -> void:
	if current_game != game:
		return
	if is_instance_valid(current_level):
		current_level.shutdown()
	_current_level_scene = null
	current_game = null
	_level_container = null
	current_level = null
	current_player = null


func load_level(scene: PackedScene) -> bool:
	if _loading or scene == null or not is_instance_valid(_level_container):
		return false
	var instance := scene.instantiate()
	if not instance is BaseLevel:
		push_error("GameHandler can only load scenes inheriting BaseLevel.")
		instance.free()
		return false

	_loading = true
	if is_instance_valid(current_level):
		var previous_level := current_level
		previous_level.shutdown()
		_level_container.remove_child(previous_level)
		previous_level.queue_free()
	_current_level_scene = scene
	current_level = instance as BaseLevel
	current_player = null
	_level_container.add_child(current_level)
	current_player = current_level.player
	_loading = false
	level_changed.emit(current_level)
	return true


func set_session_value(key: StringName, value: Variant) -> void:
	_session[key] = value
	session_value_changed.emit(key, value)


func get_session_value(key: StringName, fallback: Variant = null) -> Variant:
	return _session.get(key, fallback)


func clear_session() -> void:
	_session.clear()
	_area_progress.clear()


func store_area_progress(level_key: String, area_id: StringName, data: Dictionary) -> void:
	if not _area_progress.has(level_key):
		_area_progress[level_key] = {}
	_area_progress[level_key][area_id] = data.duplicate(true)


func get_area_progress(level_key: String, area_id: StringName) -> Dictionary:
	return (_area_progress.get(level_key, {}).get(area_id, {}) as Dictionary).duplicate(true)


func forget_area_progress(level_key: String) -> void:
	_area_progress.erase(level_key)


func restart_after_death(level: BaseLevel, progress_key: String) -> bool:
	if current_level != level or _current_level_scene == null or _loading:
		return false
	var scene := _current_level_scene
	# Shutdown saves the final active snapshot before a deliberate reset.
	level.shutdown()
	if current_level != level:
		return false
	if reset_progress_on_death:
		forget_area_progress(progress_key)
	return load_level(scene)
