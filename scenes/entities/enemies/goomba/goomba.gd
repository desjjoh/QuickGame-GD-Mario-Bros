extends BaseEnemy


func _accept_hit(hit: EntityHit) -> bool:
	if state_machine.current_state != $StateMachine/Walking and not _accepts_defeated_hit(hit):
		return false
	var reward_position := reward_popup_position(hit.maneuver != &"stomp")
	match hit.maneuver:
		&"stomp":
			if not state_machine.change_state($StateMachine/Squashed):
				return false
		&"block_bump", &"shell", &"fireball", &"star":
			var knocked_out = $StateMachine/KnockedOut
			knocked_out.launch_direction = away_from_attacker(hit)
			knocked_out.block_launch = hit.maneuver == &"block_bump"
			knocked_out.fireball_launch = hit.maneuver == &"fireball"
			knocked_out.star_launch = hit.maneuver == &"star"
			if not state_machine.change_state(knocked_out):
				return false
		_:
			return false
	mark_defeated(hit)
	if is_shutdown or is_queued_for_deletion():
		return true
	if hit.maneuver == &"stomp":
		award_stomp(hit, reward_position)
	elif hit.maneuver == &"block_bump":
		award_score(100, reward_position)
	elif hit.maneuver in [&"fireball", &"star"]:
		award_smack_defeat(100, reward_position)
	return true


func _configure_reward_popup(popup: Sprite2D) -> void:
	if state_machine.current_state != $StateMachine/Squashed:
		return
	var mario := _level.player as Mario if is_instance_valid(_level) else null
	if is_instance_valid(mario):
		popup.expire_after_intervals(mario.damage.interval_elapsed, 2)


func _can_hurt_player() -> bool:
	return state_machine.current_state == $StateMachine/Walking


func _accepts_defeated_hit(hit: EntityHit) -> bool:
	return (
		hit != null
		and hit.maneuver in [&"shell", &"star"]
		and state_machine.current_state == $StateMachine/Squashed
	)


func _blocks_enemy_contact() -> bool:
	return super() or state_machine.current_state == $StateMachine/Squashed
