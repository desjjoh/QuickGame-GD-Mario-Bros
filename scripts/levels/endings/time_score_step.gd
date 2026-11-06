class_name TimeScoreStep
extends EndingStep
## Normal ending bonus: one timer unit becomes 50 points per physics tick.

const POINTS_PER_UNIT: int = 50
const TICK_SOUND_FRAME_BIT: int = 4
var _level: WeakRef
var _started_frame: int = -1


func _ready() -> void:
	process_physics_priority = 51
	set_physics_process(false)


func _begin(ticket: int) -> void:
	var ancestor := get_parent()
	while ancestor != null and not ancestor is BaseLevel:
		ancestor = ancestor.get_parent()
	if ancestor == null:
		cancel()
		return
	_level = weakref(ancestor)
	if not _owns_conversion():
		cancel()
		return
	if not (ancestor as BaseLevel).timer_enabled or GameHandler.time_remaining == 0:
		complete(ticket)
		return
	# Retirement can happen earlier in this physics tick; start on the next one.
	_started_frame = Engine.get_physics_frames()
	set_physics_process(true)


func _owns_conversion() -> bool:
	var level := _level.get_ref() as BaseLevel if _level != null else null
	return (
		active
		and is_instance_valid(level)
		and not level.is_shutdown
		and GameHandler.current_level == level
		and level.ending_in_progress
		and GameHandler.flow == GameHandler.GameFlow.COMPLETING
	)


func _physics_process(_delta: float) -> void:
	if not _owns_conversion():
		cancel()
		return
	if Engine.get_physics_frames() <= _started_frame:
		return
	var ticket := current_ticket
	var level := _level.get_ref() as BaseLevel
	# The reference advances its ending task on the tick after the last decrement.
	if not level.timer_enabled or GameHandler.time_remaining == 0:
		complete(ticket)
		return
	GameHandler.time_remaining -= 1
	# Session observers can cancel or replace the level synchronously.
	if not _owns_conversion() or ticket != current_ticket:
		return
	if (Engine.get_physics_frames() & TICK_SOUND_FRAME_BIT) != 0:
		SoundHandler.play_reward(&"timer_tick")
	GameHandler.add_score(POINTS_PER_UNIT)


func complete(ticket: int) -> void:
	if not active or ticket != current_ticket:
		return
	set_physics_process(false)
	_level = null
	super.complete(ticket)


func cancel() -> void:
	set_physics_process(false)
	_level = null
	super.cancel()


func _exit_tree() -> void:
	cancel()
