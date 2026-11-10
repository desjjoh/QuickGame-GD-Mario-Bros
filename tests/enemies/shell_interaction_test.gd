extends Node

var level: BaseLevel


func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func koopa(x: float) -> BaseEnemy:
	var actor := (
		load("res://scenes/entities/enemies/koopa/green_koopa.tscn").instantiate() as BaseEnemy
	)
	actor.position = Vector2(x, 192)
	assert(level.try_claim_spawn_slot(&"enemy", actor))
	level.world_objects.add_child(actor)
	return actor


func _ready() -> void:
	var game_scene := load("res://tests/fixtures/silent_game.tscn") as PackedScene
	var game: Node = game_scene.instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	level = GameHandler.current_level
	var ground := level.active_area.get_node("Layouts/GroundLayout") as TileMapLayer
	ground.clear()
	for x in range(24):
		ground.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
	ground.set_cell(Vector2i(15, 12), 0, Vector2i.ZERO)
	await ticks(2)
	var player := level.player
	player.set_physics_process(false)
	var shell := koopa(120)
	assert(shell.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))
	await ticks(6)  # Settle the setup stomp before measuring the kick.
	var lives := GameHandler.player_status.lives
	var score := GameHandler.player_status.score
	player.body.global_position = Vector2(118, 204)
	player.body.velocity = Vector2.ZERO
	await ticks(4)
	assert(shell.is_moving_shell() and shell.body.velocity.x == 180)
	assert(shell._active_sound_effect.stream == SoundHandler.get_sound(&"enemy_smack"))
	await ticks(6)
	assert(GameHandler.player_status.score == score + 500 and not level.death_in_progress)
	var paused_position := shell.body.global_position
	assert(GameHandler.request_pause_toggle())
	await ticks(10)
	assert(shell.body.global_position == paused_position)
	assert(GameHandler.request_pause_toggle())
	player.body.global_position = Vector2(40, 100)
	for index in range(40):
		await ticks(1)
		if shell.body.velocity.x < 0:
			break
	assert(shell.body.velocity.x == -180)
	assert(shell._active_sound_effect.stream == SoundHandler.get_sound(&"bump"))
	shell.body.global_position = Vector2(128, 200)
	shell.get_node("StateMachine/ShellMoving")._direction = 1
	player.body.global_position = Vector2(128, 198)
	player.body.velocity = Vector2(90, 120)
	for frame in range(6):
		await ticks(1)
		if not shell.is_moving_shell():
			break
	assert(shell.state_machine.current_state.name == &"ShellIdle")
	assert(player.body.velocity == Vector2(90, -240))
	assert(not level.death_in_progress)
	player.body.global_position = Vector2(40, 100)
	await ticks(4)
	player.body.global_position = shell.body.global_position + Vector2(10, 4)
	player.body.velocity = Vector2.ZERO
	await ticks(4)
	assert(shell.is_moving_shell() and shell.body.velocity.x == -180)
	assert(GameHandler.player_status.lives == lives)
	player.body.global_position = Vector2(40, 100)
	shell.set_physics_process(false)
	var moving := shell.get_node("StateMachine/ShellMoving")
	var chain_points := [500, 800, 1000, 2000, 4000, 5000, 8000]
	var survivor := (
		load("res://scenes/entities/enemies/base/base_enemy.tscn").instantiate() as BaseEnemy
	)
	survivor.set_script(load("res://tests/fixtures/reactive_enemy.gd"))
	survivor.position = Vector2(180, 192)
	level.world_objects.add_child(survivor)
	await ticks(6)
	var survivor_score := GameHandler.player_status.score
	moving._on_enemy_contact(survivor)
	moving._on_enemy_contact(survivor)
	assert(survivor.reactions == 1 and not survivor._defeated)
	assert(GameHandler.player_status.score == survivor_score and shell.shell_chain == 0)
	survivor.free()
	var goomba_scene := load("res://scenes/entities/enemies/goomba/goomba.tscn") as PackedScene
	for index in range(9):
		var target := goomba_scene.instantiate() as BaseEnemy
		target.position = Vector2(180, 192)
		level.world_objects.add_child(target)
		var before := GameHandler.player_status.score
		var life_before := GameHandler.player_status.lives
		moving._on_enemy_contact(target)
		assert(target._defeated and target.sprite.flip_v)
		moving._on_enemy_contact(target)
		target.free()
		await ticks(6)
		if index < 7:
			assert(GameHandler.player_status.score == before + chain_points[index])
		else:
			assert(GameHandler.player_status.lives == life_before + 1)
	# Moving shell versus idle shell: only the idle target is defeated.
	var retained_chain: int = shell.shell_chain
	assert(shell.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))
	assert(shell.receive_hit(EntityHit.new(player, &"kick", Vector2.ZERO)))
	assert(shell.shell_chain == retained_chain)
	var squashed := goomba_scene.instantiate() as BaseEnemy
	squashed.position = Vector2(180, 192)
	level.world_objects.add_child(squashed)
	var defeat_events: Array[EntityHit] = []
	squashed.defeated.connect(func(hit: EntityHit): defeat_events.append(hit))
	assert(squashed.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))
	moving._on_enemy_contact(squashed)
	assert(squashed.state_machine.current_state.name == &"KnockedOut")
	assert(defeat_events.size() == 1)
	squashed.free()
	var target := koopa(180)
	assert(target.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))
	moving._on_enemy_contact(target)
	assert(target._defeated and not shell._defeated)
	target.free()
	# Moving shell versus walking Koopa.
	target = koopa(180)
	moving._on_enemy_contact(target)
	assert(target._defeated and target.state_machine.current_state.name == &"KnockedOut")
	target.free()
	# Two moving shells: mutual defeat, one 1000 award plus the source chain.
	target = koopa(180)
	assert(target.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))
	assert(target.receive_hit(EntityHit.new(player, &"kick", Vector2.ZERO)))
	shell.shell_chain = 0
	target.set_physics_process(false)
	await ticks(6)
	var before := GameHandler.player_status.score
	moving._on_enemy_contact(target)
	assert(shell._defeated and target._defeated)
	await ticks(6)
	assert(GameHandler.player_status.score == before + 1500)
	moving._on_enemy_contact(target)
	assert(GameHandler.player_status.score == before + 1500)
	game.queue_free()
	await ticks(2)
	# A fresh side overlap with a moving shell damages Mario.
	game = game_scene.instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	level = GameHandler.current_level
	player = level.player
	player.set_physics_process(false)
	shell = koopa(144)
	assert(shell.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))
	assert(shell.receive_hit(EntityHit.new(player, &"kick", Vector2.ZERO)))
	player.body.global_position = Vector2(40, 100)
	await ticks(13)
	shell.body.global_position = Vector2(152, 200)
	player.body.global_position = Vector2(159, 204)
	player.body.velocity = Vector2.ZERO
	await ticks(4)
	assert(level.death_in_progress)
	game.queue_free()
	await ticks(2)
	# A real physics overlap, including enemies already touching when kicked.
	game = game_scene.instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	level = GameHandler.current_level
	level.player.body.global_position = Vector2(40, 180)
	shell = koopa(140)
	assert(shell.receive_hit(EntityHit.new(level.player, &"stomp", Vector2.DOWN)))
	var overlap := goomba_scene.instantiate() as BaseEnemy
	overlap.position = Vector2(146, 192)
	level.world_objects.add_child(overlap)
	await ticks(6)
	before = GameHandler.player_status.score
	assert(shell.receive_hit(EntityHit.new(level.player, &"kick", Vector2.ZERO)))
	await ticks(2)
	assert(overlap._defeated and shell.is_moving_shell())
	await ticks(6)
	assert(GameHandler.player_status.score == before + 1000)
	await ticks(3)
	assert(GameHandler.player_status.score == before + 1000)
	game.queue_free()
	await ticks(2)
	await check_ledge_roll()
	print("shell_interaction_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func check_ledge_roll() -> void:
	level = preload("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	var ground := level.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
	ground.clear()
	for column in range(24):
		ground.set_cell(Vector2i(column, 13), 0, Vector2i.ZERO)
	for column in range(8, 13):
		ground.set_cell(Vector2i(column, 9), 0, Vector2i.ZERO)
	add_child(level)
	level.set_physics_process(false)
	level.active_area.set_physics_process(false)
	level.player.set_physics_process(false)
	level.player.body.global_position = Vector2(48, 100)
	await ticks(2)
	for direction: int in [-1, 1]:
		var start_x := 202.0 if direction > 0 else 133.0
		var shell := seed_rolling_shell(Vector2(start_x, 136.0), direction)
		var moving := shell.state_machine.current_state
		for tick in range(2):
			moving.process_physics(1.0 / 60.0)
			assert(moving.has_center_support and shell.body.velocity.x == direction * 180.0)
		assert(shell.body.global_position.x == start_x + direction * 6.0)
		for tick in range(28):
			var previous_x := shell.body.global_position.x
			moving.process_physics(1.0 / 60.0)
			assert(not moving.has_center_support and shell.body.velocity.x == direction * 90.0)
			assert(shell.body.global_position.x == previous_x + direction * 1.5)
		var before_landing := shell.body.global_position.x
		moving.process_physics(1.0 / 60.0)
		assert(moving.has_center_support and shell.body.velocity.x == direction * 180.0)
		assert(shell.body.global_position == Vector2(before_landing + direction * 3.0, 200.0))
		shell.free()
	await check_flat_wall_roll(ground)
	level.free()


func check_flat_wall_roll(ground: TileMapLayer) -> void:
	for column in [4, 12]:
		for row in [11, 12]:
			ground.set_cell(Vector2i(column, row), 0, Vector2i.ZERO)
	await ticks(2)
	for direction: int in [-1, 1]:
		var start_x := 170.0 if direction > 0 else 102.0
		var shell := seed_rolling_shell(Vector2(start_x, 200.0), direction)
		var moving := shell.state_machine.current_state
		for tick in range(5):
			moving.process_physics(1.0 / 60.0)
			assert(shell.body.velocity.x == direction * 180.0)
		moving.process_physics(1.0 / 60.0)
		assert(shell.body.velocity.x == -direction * 180.0)
		assert(shell.body.global_position.x == start_x + direction * 12.0)
		shell.free()

	# The right wall is in reach when support returns. It turns the shell on the following tick.
	var shell := seed_rolling_shell(Vector2(183.5, 199.0), 1)
	var moving := shell.state_machine.current_state
	shell.body.velocity.y = 120.0
	moving.process_physics(1.0 / 60.0)
	assert(shell.body.global_position == Vector2(185.0, 201.0))
	moving.process_physics(1.0 / 60.0)
	assert(shell.body.global_position == Vector2(188.0, 200.0))
	assert(shell.body.velocity == Vector2(180.0, 0.0))
	moving.process_physics(1.0 / 60.0)
	assert(shell.body.global_position == Vector2(185.0, 200.0))
	assert(shell.body.velocity == Vector2(-180.0, 0.0))
	shell.free()


func seed_rolling_shell(center: Vector2, direction: int) -> BaseEnemy:
	var shell := koopa(center.x - 8.0)
	shell.set_physics_process(false)
	shell.body.global_position = center
	var moving := shell.get_node("StateMachine/ShellMoving")
	moving.initial_direction = direction
	assert(shell.state_machine.change_state(moving))
	return shell
