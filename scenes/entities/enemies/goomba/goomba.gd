extends BaseEnemy

const SCORE_POPUP := preload("res://scenes/components/presentation/score_popup.tscn")


func _accept_hit(hit: EntityHit) -> bool:
	if state_machine.current_state != $StateMachine/Walking:
		return false
	match hit.maneuver:
		&"stomp":
			state_machine.change_state($StateMachine/Squashed)
		&"block_bump", &"shell", &"fireball", &"star":
			var knocked_out: EnemyDefeatedState = $StateMachine/KnockedOut
			var attacker_x := body.global_position.x
			if hit.attacker is BasePlayer:
				attacker_x = hit.attacker.body.global_position.x
			elif is_instance_valid(hit.attacker):
				attacker_x = hit.attacker.global_position.x
			knocked_out.launch_direction = -1.0 if body.global_position.x < attacker_x else 1.0
			state_machine.change_state(knocked_out)
		_:
			return false
	if hit.maneuver == &"stomp" or hit.maneuver == &"block_bump":
		var popup := SCORE_POPUP.instantiate()
		get_parent().add_child(popup)
		popup.show_score(100, sprite.global_position)
		var rise := popup.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		rise.tween_property(popup, "position:y", popup.position.y - 24.0, 0.8)
		rise.tween_callback(popup.queue_free)
		GameHandler.add_score(100)
	return true


func _can_hurt_player() -> bool:
	return state_machine.current_state == $StateMachine/Walking
