extends Node


func _ready() -> void:
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	var level: BaseLevel = GameHandler.current_level
	var player := level.player
	player.set_physics_process(false)
	player.body.global_position = Vector2(24, 100)
	# Expected values are the reference score controls 3 + StompChainCounter.
	var awards := [400, 500, 800, 1000, 2000, 4000, 5000, 8000, 0, 0]
	for count in range(awards.size()):
		check_kick(level, count, 336, awards[count])
	# Bonus boundaries override even a chain that would normally award a life.
	check_kick(level, 0, 43, 400)
	check_kick(level, 0, 42, 500)
	check_kick(level, 8, 22, 500)
	check_kick(level, 0, 21, 1000)
	check_kick(level, 8, 1, 1000)
	# Zero is the reference table entry; normal gameplay wakes before contact.
	check_kick(level, 0, 0, 8000)
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("shell_kick_score_test: PASS")
	get_tree().quit()


func check_kick(level: BaseLevel, count: int, remaining: int, points: int) -> void:
	var enemy := (
		load("res://scenes/entities/enemies/koopa/green_koopa.tscn").instantiate() as BaseEnemy
	)
	enemy.position = Vector2(144, 160)
	level.world_objects.add_child(enemy)
	var player := level.player
	assert(enemy.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))
	player.stomp_chain = count
	enemy.get_node("StateMachine/ShellIdle").wake_ticks_remaining = remaining
	var score := GameHandler.player_status.score
	var lives := GameHandler.player_status.lives
	assert(enemy.receive_hit(EntityHit.new(player, &"kick", Vector2.ZERO)))
	assert(enemy.is_moving_shell() and enemy.body.velocity.x == 180)
	assert(GameHandler.player_status.score == score + points)
	assert(GameHandler.player_status.lives == lives + (1 if points == 0 else 0))
	assert(player.stomp_chain == count and enemy.shell_chain == 0)
	assert(not enemy.receive_hit(EntityHit.new(player, &"kick", Vector2.ZERO)))
	assert(GameHandler.player_status.score == score + points)
	enemy.free()
