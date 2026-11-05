class_name EndingStep
extends Node
## Override _begin(ticket); report completion with complete(ticket).

signal finished(ticket: int)
var current_ticket: int = 0
var active: bool = false


func begin() -> void:
	current_ticket += 1
	active = true
	_begin(current_ticket)


func _begin(ticket: int) -> void:
	# The base hook is a no-op; derived steps implement their own presentation.
	complete(ticket)


func complete(ticket: int) -> void:
	if not active or ticket != current_ticket:
		return
	active = false
	finished.emit(ticket)


func cancel() -> void:
	active = false
	current_ticket += 1
