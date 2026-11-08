extends "res://scripts/states/blocks/active_block_state.gd"
## Only ordinary bricks opt into form-dependent breaking.
@export var broken_state: BaseState


func receive_hit(hit: EntityHit) -> bool:
	if hit == null or hit.maneuver != accepted_maneuver or hit.direction.y >= 0:
		return false
	var mario := hit.attacker as Mario
	if mario != null and mario.form_controller.current_form.can_break_bricks:
		(entity as BaseBlock).bonk_velocity_y = -120.0
		return state_machine.change_state(broken_state)
	return super.receive_hit(hit)
