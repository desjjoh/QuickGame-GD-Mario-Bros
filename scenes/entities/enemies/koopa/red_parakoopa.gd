extends "res://scenes/entities/enemies/koopa/koopa.gd"


func _can_hurt_player() -> bool:
	return state_machine.current_state == $StateMachine/Flying or super()


func projectile_target_bounds() -> Rect2:
	if state_machine.current_state == $StateMachine/Flying:
		return PLAYER_CONTACT.bounds(_player_contact_shape)
	return super()


func _accept_hit(hit: EntityHit) -> bool:
	if hit.maneuver != &"stomp" or state_machine.current_state != $StateMachine/Flying:
		return super(hit)
	var walking := $StateMachine/Walking
	var reward_position := reward_popup_position()
	if hit.attacker is BasePlayer:
		walking.initial_direction = -int(away_from_attacker(hit))
	if not state_machine.change_state(walking):
		return false
	award_score(400, reward_position)
	return true
