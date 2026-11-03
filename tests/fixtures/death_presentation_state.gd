extends PlayerState
var ticks: int = 0
func process_physics(_delta: float) -> BaseState:
	ticks += 1
	return null
