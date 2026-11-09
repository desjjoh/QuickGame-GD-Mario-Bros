extends Node
## Delays an entity-selected award independently of its actor and popup.

const DELAY_TICKS := 6
var _remaining_ticks := DELAY_TICKS
var _created_tick: int
var _reward: Callable
var _level: BaseLevel


static func schedule(source: Node, reward: Callable, delay_ticks: int = DELAY_TICKS) -> void:
	var pending := new()
	pending._remaining_ticks = maxi(1, delay_ticks)
	pending._reward = reward
	pending._created_tick = Engine.get_physics_frames()
	pending.process_mode = Node.PROCESS_MODE_PAUSABLE
	var parent := source.get_parent()
	var level := BaseLevel.containing(source)
	if level != null:
		pending._level = level
		parent = level.get_node("Systems")
	parent.add_child(pending)


func _physics_process(_delta: float) -> void:
	if is_instance_valid(_level) and _level.is_shutdown:
		queue_free()
		return
	# Never count the creation frame, regardless of scene-tree processing order.
	if Engine.get_physics_frames() == _created_tick:
		return
	_remaining_ticks -= 1
	if _remaining_ticks == 0:
		set_physics_process(false)
		if _reward.is_valid():
			_reward.call()
		_reward = Callable()
		queue_free()
