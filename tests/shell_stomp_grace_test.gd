extends Node


func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	var level: BaseLevel = GameHandler.current_level
	var player := level.player
	player.set_physics_process(false)
	player.body.global_position = Vector2(24, 100)
	var scene := load("res://scenes/entities/enemies/koopa/green_koopa.tscn") as PackedScene
	var shell := scene.instantiate() as BaseEnemy
	shell.position = Vector2(144, 192)
	level.world_objects.add_child(shell)
	var other := scene.instantiate() as BaseEnemy
	other.position = Vector2(208, 192)
	level.world_objects.add_child(other)
	assert(shell.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))
	assert(shell.get("stomp_grace_ticks") == 12)
	await ticks(4)
	var remaining: int = shell.get("stomp_grace_ticks")
	assert(remaining > 0 and remaining < 12)
	assert(shell.receive_hit(EntityHit.new(player, &"kick", Vector2.ZERO)))
	assert(shell.get("stomp_grace_ticks") == remaining)
	player.body.velocity = Vector2(0, -60)
	assert(shell._can_stomp(player) and not other._can_stomp(player))
	assert(other.state_machine.change_state(other.get_node("StateMachine/ShellIdle")))
	assert(other.receive_hit(EntityHit.new(player, &"kick", Vector2.ZERO)))
	assert(not other._can_stomp(player))
	other.free()
	assert(GameHandler.request_pause_toggle())
	await ticks(12)
	assert(shell.get("stomp_grace_ticks") == remaining)
	assert(GameHandler.request_pause_toggle())
	# Actual fresh overlap while rising must stop this shell and bounce Mario.
	player.body.global_position = shell.body.global_position + Vector2(0, -5)
	var score := GameHandler.player_status.score
	for index in range(4):
		await ticks(1)
		if not shell.is_moving_shell():
			break
	assert(not shell.is_moving_shell() and not level.death_in_progress)
	assert(player.body.velocity.y == -240)
	assert(GameHandler.player_status.score == score + 200)
	assert(shell.get("stomp_grace_ticks") == 12)
	# Remaining in contact cannot immediately kick or award another reward.
	await ticks(4)
	assert(not shell.is_moving_shell() and GameHandler.player_status.score == score + 200)
	player.body.global_position = Vector2(24, 100)
	await ticks(2)
	assert(shell.receive_hit(EntityHit.new(player, &"kick", Vector2.ZERO)))
	remaining = shell.get("stomp_grace_ticks")
	await ticks(remaining - 1)
	assert(shell.get("stomp_grace_ticks") == 1)
	await ticks(1)
	assert(shell.get("stomp_grace_ticks") == 0)
	player.body.velocity = Vector2.ZERO
	assert(not shell._can_stomp(player))
	# A real stop after expiry still works while descending and refreshes grace.
	player.body.velocity.y = 120
	shell._handle_player_contact(player)
	assert(not shell.is_moving_shell() and shell.get("stomp_grace_ticks") == 12)
	assert(shell.state_machine.change_state(shell.get_node("StateMachine/Walking")))
	await ticks(1)
	assert(shell.get("stomp_grace_ticks") == 0)
	game.queue_free()
	await ticks(2)
	print("shell_stomp_grace_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
