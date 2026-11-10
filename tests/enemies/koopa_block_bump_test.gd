extends Node

signal physics_step_finished


func _physics_process(_delta: float) -> void:
	physics_step_finished.emit()


func ticks(count: int) -> void:
	for frame in range(count):
		await physics_step_finished


func spawn(level: BaseLevel) -> BaseEnemy:
	var enemy := (
		load("res://scenes/entities/enemies/koopa/green_koopa.tscn").instantiate() as BaseEnemy
	)
	enemy.position = Vector2(144, 192)
	assert(level.try_claim_spawn_slot(&"enemy", enemy))
	level.world_objects.add_child(enemy)
	return enemy


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 200
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	var level: BaseLevel = GameHandler.current_level
	var player := level.player
	# Scripted attacker placement selects hit direction, not camera scrolling.
	(level.active_area.get_node("Camera2D") as LevelCamera).follow_enabled = false
	# Freeze the actor and its child state machine during scripted block interactions.
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.body.global_position = Vector2(24, 100)
	var enemy := spawn(level)
	var bump := EntityHit.new(player, &"block_bump", Vector2.UP)
	var score := GameHandler.player_status.score
	var before := enemy.body.global_position
	var pose_position := enemy.sprite.global_position
	enemy.get_node("Body/BlockHitReceiver").receive_hit(bump)
	assert(enemy.state_machine.current_state.name == &"ShellStunned")
	assert(enemy.body.global_position.is_equal_approx(before + Vector2(1, -5)))
	assert(enemy.body.velocity == Vector2(60, -165.703125))
	assert(not enemy.sprite.flip_v and enemy.sprite.vframes == 1)
	assert(enemy.sprite.global_position.is_equal_approx(pose_position))
	assert(not enemy._defeated and level.spawn_registry._live_spawns[&"enemy"].has(enemy))
	assert(GameHandler.player_status.score == score)
	assert(enemy.get_node("StateMachine/ShellIdle").wake_ticks_remaining == 0)
	# Repeat bumps reapply the impulse and award once each, including opposite direction.
	player.body.global_position.x = 240
	before = enemy.body.global_position
	assert(enemy.receive_hit(bump))
	assert(enemy.body.global_position.is_equal_approx(before + Vector2(-1, -5)))
	assert(enemy.body.velocity == Vector2(-60, -165.703125))
	assert(GameHandler.player_status.score == score)
	var position := enemy.body.global_position
	assert(GameHandler.request_pause_toggle())
	await ticks(12)
	assert(enemy.body.global_position == position)
	assert(GameHandler.request_pause_toggle())
	await ticks(1)
	assert(
		enemy.sprite.flip_v and enemy.sprite.frame == 4 and enemy.sprite.position == Vector2.ZERO
	)
	await ticks(5)
	assert(GameHandler.player_status.score == score + 200)
	for index in range(90):
		await ticks(1)
		if enemy.state_machine.current_state.name == &"ShellIdle":
			break
	assert(enemy.state_machine.current_state.name == &"ShellIdle")
	assert(enemy.body.velocity.x == 0 and enemy.sprite.flip_v)
	assert(enemy.get_node("StateMachine/ShellIdle").wake_ticks_remaining == 336)
	assert(enemy.receive_hit(bump))
	assert(enemy.state_machine.current_state.name == &"ShellStunned")
	assert(enemy.receive_hit(EntityHit.new(player, &"kick", Vector2.ZERO)))
	assert(enemy.is_moving_shell() and enemy.sprite.flip_v)
	assert(enemy.body.velocity.x == -180)
	await ticks(1)  # Deliver the bonk after the shell's update for this tick.
	assert(enemy.receive_hit(bump))
	assert(enemy.is_moving_shell() and enemy._can_hurt_player())
	assert(enemy.body.velocity == Vector2(-60, -180))
	assert(enemy.get_node("StateMachine/ShellMoving").walk_speed == 60)
	var launch_position := enemy.body.global_position
	await ticks(1)
	assert(enemy.body.global_position.is_equal_approx(launch_position + Vector2(0.5, -3.0)))
	var target := (
		load("res://scenes/entities/enemies/goomba/goomba.tscn").instantiate() as BaseEnemy
	)
	target.position = Vector2(192, 192)
	level.world_objects.add_child(target)
	enemy.get_node("StateMachine/ShellMoving")._on_enemy_contact(target)
	assert(target._defeated and enemy.get("shell_chain") == 1)
	assert(enemy.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))
	assert(not enemy.sprite.flip_v)
	assert(enemy.receive_hit(EntityHit.new(player, &"kick", Vector2.ZERO)))
	assert(absf(enemy.body.velocity.x) == 180)
	enemy.free()
	await ticks(6)
	# A newly block-stunned walking Koopa has no recovery interval until landing.
	player.body.global_position = Vector2(24, 100)
	enemy = spawn(level)
	assert(enemy.receive_hit(bump))
	await ticks(6)
	score = GameHandler.player_status.score
	assert(enemy.receive_hit(EntityHit.new(player, &"kick", Vector2.ZERO)))
	await ticks(6)
	assert(GameHandler.player_status.score == score + 8000)
	enemy.free()
	enemy = spawn(level)
	assert(enemy.receive_hit(bump))
	enemy.body.global_position = Vector2(152, 200)
	enemy.body.velocity = Vector2(60, 120)
	await ticks(2)
	assert(enemy.state_machine.current_state.name == &"ShellIdle")
	enemy.get_node("StateMachine/ShellIdle").wake_ticks_remaining = 1
	await ticks(1)
	assert(enemy.state_machine.current_state.name == &"Walking")
	assert(not enemy.sprite.flip_v and enemy.sprite.vframes == 1)
	assert(enemy.get_node("Presentation/WalkAnimationSync").enabled)
	# Exercise the real bonk -> block query -> receiver route as well.
	enemy.free()
	var block := (
		load("res://scenes/entities/blocks/brick/brick_block.tscn").instantiate() as BaseBlock
	)
	block.position = Vector2(192, 112)
	level.world_objects.add_child(block)
	enemy = spawn(level)
	enemy.body.global_position = Vector2(200, 104)
	enemy.get_node("StateMachine/Walking").walk_speed = 0.0
	await ticks(2)
	await ticks(6)
	score = GameHandler.player_status.score
	assert(block.receive_hit(EntityHit.new(player, &"bonk", Vector2.UP)))
	assert(enemy.state_machine.current_state.name == &"ShellStunned")
	assert(enemy.body.velocity == Vector2(60, -165.703125))
	await ticks(6)
	assert(GameHandler.player_status.score == score + 100)
	game.queue_free()
	await ticks(2)
	print("koopa_block_bump_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
