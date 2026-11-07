extends BaseEnemy

const STOMP_GRACE_TICKS := 12
var stomp_grace_ticks := 0
var _last_shell_stomp_tick := -1
var shell_chain := 0
var shell_upside_down := false


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _defeated or state_machine.current_state == $StateMachine/Walking:
		stomp_grace_ticks = 0
	elif _last_shell_stomp_tick != Engine.get_physics_frames():
		stomp_grace_ticks = maxi(0, stomp_grace_ticks - 1)


func _can_stomp(player: BasePlayer) -> bool:
	return super._can_stomp(player) or (is_moving_shell() and stomp_grace_ticks > 0)


func _can_hurt_player() -> bool:
	return state_machine.current_state in [$StateMachine/Walking, $StateMachine/ShellMoving]


func _has_player_contact() -> bool:
	return not _defeated


func is_moving_shell() -> bool:
	return state_machine.current_state == $StateMachine/ShellMoving


func _handle_player_contact(player: BasePlayer) -> void:
	if state_machine.current_state in [$StateMachine/ShellIdle, $StateMachine/ShellStunned]:
		receive_hit(EntityHit.new(player, &"kick", Vector2.ZERO))
	else:
		super._handle_player_contact(player)


func _accept_hit(hit: EntityHit) -> bool:
	var reward_position := sprite.global_position
	if hit.maneuver == &"block_bump":
		return _accept_block_bump(hit, reward_position)
	if hit.maneuver == &"shell":
		var knocked_out := $StateMachine/KnockedOut as EnemyDefeatedState
		knocked_out.launch_direction = away_from_attacker(hit)
		if not state_machine.change_state(knocked_out):
			return false
		stomp_grace_ticks = 0
		mark_defeated(hit)
		return true
	if (
		hit.maneuver == &"kick"
		and state_machine.current_state in [$StateMachine/ShellIdle, $StateMachine/ShellStunned]
	):
		var remaining: int = $StateMachine/ShellIdle.wake_ticks_remaining
		var interval := ceili(float(remaining) / 21.0)
		$StateMachine/ShellMoving.initial_direction = int(away_from_attacker(hit))
		if not state_machine.change_state($StateMachine/ShellMoving):
			return false
		play_sound_effect(SoundHandler.get_sound(&"enemy_smack"))
		if hit.attacker is BasePlayer:
			hit.attacker.award_shell_kick(self, reward_position, interval)
		else:
			award_score(400, reward_position)
		return true
	if (
		hit.maneuver == &"stomp"
		and state_machine.current_state in [$StateMachine/Walking, $StateMachine/ShellMoving]
	):
		shell_upside_down = false
		if not state_machine.change_state($StateMachine/ShellIdle):
			return false
		stomp_grace_ticks = STOMP_GRACE_TICKS
		_last_shell_stomp_tick = Engine.get_physics_frames()
		award_stomp(hit, reward_position)
		return true
	return false


func _accept_block_bump(hit: EntityHit, reward_position: Vector2) -> bool:
	var previous := state_machine.current_state
	if (
		previous
		not in [
			$StateMachine/Walking,
			$StateMachine/ShellIdle,
			$StateMachine/ShellStunned,
			$StateMachine/ShellMoving
		]
	):
		return false
	var direction := int(away_from_attacker(hit))
	if previous == $StateMachine/Walking:
		$StateMachine/ShellIdle.wake_ticks_remaining = 0
	shell_upside_down = true
	if previous == $StateMachine/ShellMoving:
		$StateMachine/ShellMoving.walk_speed = 60.0
		$StateMachine/ShellMoving._direction = direction
	else:
		$StateMachine/ShellStunned.initial_direction = direction
		if previous != $StateMachine/ShellStunned:
			if not state_machine.change_state($StateMachine/ShellStunned):
				return false
		else:
			$StateMachine/ShellStunned._direction = direction
	sprite.flip_v = true
	body.position.y -= 2.0
	body.velocity = Vector2(60.0 * direction, -180.0)
	award_score(100, reward_position)
	return true
