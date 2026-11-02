extends EntityState
## Reusable block hit acceptance; the reaction state owns recovery.

@export var reaction_state: BaseState
@export var accepted_maneuver: StringName = &"bonk"


func receive_hit(hit: EntityHit) -> bool:
	if hit == null or hit.maneuver != accepted_maneuver or hit.direction.y >= 0.0:
		return false
	return state_machine.change_state(reaction_state)
