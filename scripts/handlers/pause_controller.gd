extends "res://scripts/session/scene_pause_controller.gd"
## Applies Mario's pause policy, input mapping, and audio to the shared controller.

var _standalone: WeakRef


func _ready() -> void:
	super()
	lockout_seconds = 43.0 / 60.0
	pause_changed.connect(GameHandler.notify_pause_changed)


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


func toggle() -> bool:
	set_pause_owner(_level())
	if not super():
		return false
	SoundHandler.play_pause()
	return true


func clear_for_level(level: BaseLevel) -> void:
	clear_for_owner(level)
	if _standalone != null and _standalone.get_ref() == level:
		_standalone = null


func _level() -> BaseLevel:
	if is_instance_valid(GameHandler.current_level):
		return GameHandler.current_level
	return _standalone.get_ref() as BaseLevel if _standalone != null else null


func _pause_input_action() -> StringName:
	return ControllerHandler.start_action


func _consume_pause_input() -> void:
	ControllerHandler.consume_menu_confirmation()


func _on_pause_cleared(was_paused: bool) -> void:
	SoundHandler.stop_pause()
	if was_paused:
		_consume_pause_input()
