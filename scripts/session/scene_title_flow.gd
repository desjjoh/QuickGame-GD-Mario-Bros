extends Node
## Owns the title screen lifecycle and handoff from a visible title into gameplay.

var screen: Control
var _start_id: int = 0


func detach() -> void:
	_clear_title()


func reveal() -> void:
	if is_instance_valid(screen):
		screen.show()


func can_start() -> bool:
	return is_instance_valid(screen) and screen.is_visible_in_tree()


func _clear_title() -> void:
	_start_id += 1
	if is_instance_valid(screen):
		screen.hide()
		screen.queue_free()
	screen = null


func mount_title(title: Control, container: Node, hidden: bool = false) -> void:
	if screen != title:
		_clear_title()
		screen = title
	if hidden:
		screen.hide()
	container.add_child(screen)


## The optional transition request receives the operation and its completion callback.
## It returns a positive ticket on acceptance, or zero on rejection.
func start(operation: Callable, request_transition: Callable = Callable()) -> bool:
	if not can_start() or not operation.is_valid():
		return false
	return _run_start(operation, request_transition)


func _run_start(operation: Callable, request_transition: Callable = Callable()) -> bool:
	screen.hide()
	_start_id += 1
	var complete := _complete_start.bind(_start_id)
	if not request_transition.is_valid():
		request_transition = _get_transition_request()
	if request_transition.is_valid():
		var ticket: int = request_transition.call(operation, complete)
		if ticket == 0:
			complete.call(false)
		return ticket > 0
	var success: bool = operation.call()
	complete.call(success)
	return success


func _get_transition_request() -> Callable:
	return Callable()


func _complete_start(success: bool, start_id: int) -> void:
	if start_id != _start_id:
		return
	_start_id += 1
	_reset_start_selection()
	if not _can_finish_start():
		return
	if success:
		_clear_title()
		_on_start_succeeded()
	else:
		_on_start_failed()


func _reset_start_selection() -> void:
	pass


func _can_finish_start() -> bool:
	return true


func _on_start_succeeded() -> void:
	pass


func _on_start_failed() -> void:
	reveal()
