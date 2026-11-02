class_name EntityState
extends BaseState
## Extension point for behavior shared by specialized entity states.
## BaseState owns common presentation and lifecycle hooks.


func receive_hit(_hit: EntityHit) -> bool:
	return false
