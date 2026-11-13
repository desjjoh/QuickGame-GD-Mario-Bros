extends Node
## Pauses the SceneTree on behalf of an explicitly supplied owner.

signal pause_changed(paused: bool)

@export var pause_action: StringName
@export var lockout_seconds: float = 0.0

var paused: bool = false
var _owner_ref: WeakRef
var _source: WeakRef
var _requires_release: bool = false
var _lockout: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_pause_owner(pause_owner: Node) -> void:
	_owner_ref = weakref(pause_owner) if is_instance_valid(pause_owner) else null


func can_pause() -> bool:
	return _owner_ref != null and is_instance_valid(_owner_ref.get_ref())


func _process(delta: float) -> void:
	_lockout = maxf(0.0, _lockout - delta)
	if paused and (_source == null or not is_instance_valid(_source.get_ref())):
		clear()


func _input(event: InputEvent) -> void:
	var action := _pause_input_action()
	if action == &"" or not InputMap.has_action(action):
		return
	if event.is_action_released(action):
		_requires_release = false
	if not event.is_action_pressed(action) or event.is_echo():
		return
	if not paused and not can_pause():
		return
	get_viewport().set_input_as_handled()
	_consume_pause_input()
	if _requires_release or _lockout > 0.0:
		return
	_requires_release = true
	toggle()


func toggle() -> bool:
	if (
		not paused
		and (not can_pause() or _owner_ref == null or not is_instance_valid(_owner_ref.get_ref()))
	):
		return false
	paused = not paused
	_source = _owner_ref if paused else null
	_consume_pause_input()
	get_tree().paused = paused
	_lockout = lockout_seconds
	pause_changed.emit(paused)
	return true


func clear_for_owner(pause_owner: Node) -> void:
	if _source != null and _source.get_ref() == pause_owner:
		clear()
	if _owner_ref != null and _owner_ref.get_ref() == pause_owner:
		_owner_ref = null


func clear() -> void:
	var was_paused := paused
	paused = false
	_source = null
	_lockout = 0.0
	get_tree().paused = false
	_on_pause_cleared(was_paused)
	if was_paused:
		pause_changed.emit(false)


func _pause_input_action() -> StringName:
	return pause_action


func _consume_pause_input() -> void:
	pass


func _on_pause_cleared(_was_paused: bool) -> void:
	pass
