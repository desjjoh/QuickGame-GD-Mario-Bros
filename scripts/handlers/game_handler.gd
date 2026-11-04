extends Node
## Global game ownership and in-memory session data. No disk persistence yet.

enum GameFlow { DETACHED, TITLE, STARTING, PLAYING }
signal flow_changed(value: GameFlow)
var flow: GameFlow = GameFlow.DETACHED
var _title_screen: Control
var _first_level: PackedScene
var _detaching: bool = false

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
# Load the coordinator at runtime: it refers back to GameHandler/BaseLevel.
# Keeping it out of this autoload's static dependency graph avoids a script
# resource cycle surviving engine shutdown.
var transitions: Variant
# Global world-progress policy; session counters/lives are unaffected.
var reset_progress_on_death: bool = false
var _current_level_scene: PackedScene


func _ready() -> void:
	transitions = load("res://scripts/handlers/transition_coordinator.gd").new()
	animation_clock.name = "AnimationClock"
	add_child(animation_clock)
	transitions.name = "Transitions"
	add_child(transitions)


func attach_game(game: Node, level_container: Node2D) -> void:
	current_game = game
	_level_container = level_container
	_detaching = false
	_set_flow(GameFlow.DETACHED)


func detach_game(game: Node) -> void:
	if current_game != game:
		return
	_detaching = true
	transitions.detach_game(game)
	_clear_title()
	_first_level = null
	if is_instance_valid(current_level):
		current_level.shutdown()
	_current_level_scene = null
	current_game = null
	_level_container = null
	current_level = null
	current_player = null
	_set_flow(GameFlow.DETACHED)


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
	if transitions.available():
		return transitions.begin(level, _restart_death_now.bind(level,progress_key), &"level") > 0
	return _restart_death_now(level,progress_key)


func _restart_death_now(level: BaseLevel, progress_key: String) -> bool:
	if current_level != level or _current_level_scene == null:
		return false
	var scene := _current_level_scene
	# Shutdown saves the final active snapshot before a deliberate reset.
	level.shutdown()
	if current_level != level:
		return false
	if reset_progress_on_death:
		forget_area_progress(progress_key)
	return load_level(scene)


func transition_to_level(scene: PackedScene) -> bool:
	if scene == null: return false
	if transitions.available():
		var transition_owner := current_level as Node if is_instance_valid(current_level) else current_game
		return transitions.begin(transition_owner, load_level.bind(scene), &"level") > 0
	return load_level(scene)


func _set_flow(value: GameFlow) -> void:
	if flow == value: return
	flow = value
	flow_changed.emit(value)


func _clear_title() -> void:
	if is_instance_valid(_title_screen):
		_title_screen.hide()
		_title_screen.queue_free()
	_title_screen = null


func start_game_flow(first_level: PackedScene, with_title: bool = true) -> bool:
	if with_title: return show_title(first_level)
	_set_flow(GameFlow.PLAYING)
	return transition_to_level(first_level)


func show_title(first_level: PackedScene) -> bool:
	if _detaching or first_level == null or not is_instance_valid(current_game) or transitions.busy: return false
	_clear_title()
	_first_level = first_level
	# Runtime loading keeps UI/level dependencies out of autoload construction.
	var screen := load("res://scenes/ui/title/title_screen.tscn").instantiate() as Control
	if screen == null: return false
	_title_screen = screen
	_set_flow(GameFlow.TITLE)
	if not load_level(screen.background_level):
		_clear_title()
		return false
	current_player.set_gameplay_suspended(true)
	current_level.set_physics_process(false)
	screen.connect(&"start_requested",start_new_game)
	current_game.get_node("UI/ScreenContainer").add_child(screen)
	return true


func start_new_game() -> bool:
	if flow != GameFlow.TITLE or _detaching or not is_instance_valid(_title_screen) or transitions.busy: return false
	if not _title_screen.is_visible_in_tree(): return false
	ControllerHandler.consume_menu_confirmation()
	_set_flow(GameFlow.STARTING)
	_title_screen.hide()
	if transitions.available():
		var accepted: int = transitions.begin(current_game,_load_first_level,&"level",_start_finished)
		if accepted == 0: _start_finished(false)
		return accepted > 0
	var success := _load_first_level()
	_start_finished(success)
	return success


func _load_first_level() -> bool:
	if flow != GameFlow.STARTING or _detaching or _first_level == null: return false
	# Shutdown saves old progress before the new session deliberately clears it.
	if is_instance_valid(current_level): current_level.shutdown()
	clear_session()
	return load_level(_first_level)


func _start_finished(success: bool) -> void:
	if _detaching or not is_instance_valid(current_game): return
	if success:
		_clear_title()
		_set_flow(GameFlow.PLAYING)
	else:
		# Cancellation can originate inside a level's _exit_tree. Restore UI
		# only after that tree operation completes, and only for this Game.
		_restore_title.call_deferred(weakref(current_game),_first_level)


func _restore_title(expected_game: WeakRef, first_level: PackedScene) -> void:
	var game := expected_game.get_ref() as Node
	if _detaching or flow != GameFlow.STARTING or not is_instance_valid(game) or current_game != game: return
	show_title(first_level)
