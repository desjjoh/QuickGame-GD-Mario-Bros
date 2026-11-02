extends Node
## Global game ownership and in-memory session data. No disk persistence yet.

signal level_changed(level: BaseLevel)
signal session_value_changed(key: StringName, value: Variant)

var current_game: Node
var current_level: BaseLevel
var current_player: BasePlayer
var _level_container: Node2D
var _session: Dictionary[StringName, Variant] = {}
var _loading: bool = false


func attach_game(game: Node, level_container: Node2D) -> void:
	current_game = game
	_level_container = level_container


func detach_game(game: Node) -> void:
	if current_game != game:
		return
	if is_instance_valid(current_level):
		current_level.shutdown()
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
