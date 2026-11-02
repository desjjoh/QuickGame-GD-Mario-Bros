extends EntityState
## Owns the reaction phase; entry presentation/signals come from BaseState.

signal bounce_completed

var _completed: bool = false

@export var return_state: BaseState


func enter() -> void:
	_completed = false
	var block := entity as BaseBlock
	block.bounce.begin(block.sprite)


func process_physics(delta: float) -> BaseState:
	var bounce := (entity as BaseBlock).bounce
	bounce.advance(delta)
	if not bounce.is_running() and not _completed:
		_completed = true
		bounce_completed.emit()
		return return_state
	return null


func exit() -> void:
	(entity as BaseBlock).bounce.reset()
