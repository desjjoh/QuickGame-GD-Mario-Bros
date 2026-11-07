extends Node
## Only this listener and the dedicated pause voice keep running during pause.

var paused: bool = false
var _source: WeakRef
var _standalone: WeakRef
var _requires_release: bool = false
var _lockout: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func register_level(level: BaseLevel) -> void:
	_standalone = weakref(level)


func can_pause() -> bool:
	var level := _level()
	return (
		is_instance_valid(level)
		and not level.is_shutdown
		and not GameHandler.transitions.busy
		and (
			not is_instance_valid(GameHandler.current_game)
			or GameHandler.flow != GameHandler.GameFlow.TITLE
		)
	)


func _level() -> BaseLevel:
	if is_instance_valid(GameHandler.current_level):
		return GameHandler.current_level
	return _standalone.get_ref() as BaseLevel if _standalone != null else null


func _process(delta: float) -> void:
	_lockout = maxf(0.0, _lockout - delta)
	if paused and (_source == null or not is_instance_valid(_source.get_ref())):
		clear()


func _input(event: InputEvent) -> void:
	var action := ControllerHandler.start_action
	if action == &"" or not InputMap.has_action(action):
		return
	if event.is_action_released(action):
		_requires_release = false
	if not event.is_action_pressed(action) or event.is_echo():
		return
	if not paused and not can_pause():
		return
	get_viewport().set_input_as_handled()
	ControllerHandler.consume_menu_confirmation()
	if _requires_release or _lockout > 0.0:
		return
	_requires_release = true
	toggle()


func toggle() -> bool:
	if not paused and not can_pause():
		return false
	paused = not paused
	_source = weakref(_level()) if paused else null
	ControllerHandler.consume_menu_confirmation()
	get_tree().paused = paused
	_lockout = 43.0 / 60.0
	GameHandler.notify_pause_changed(paused)
	SoundHandler.play_pause()
	return true


func clear_for_level(level: BaseLevel) -> void:
	if _source != null and _source.get_ref() == level:
		clear()
	if _standalone != null and _standalone.get_ref() == level:
		_standalone = null


func clear() -> void:
	var was_paused := paused
	paused = false
	_source = null
	_lockout = 0.0
	get_tree().paused = false
	SoundHandler.stop_pause()
	if was_paused:
		ControllerHandler.consume_menu_confirmation()
		GameHandler.notify_pause_changed(false)
