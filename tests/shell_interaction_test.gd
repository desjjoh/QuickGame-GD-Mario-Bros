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
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
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
	var lives := GameHandler.player_status.lives
	var score := GameHandler.player_status.score
	player.body.global_position = Vector2(118, 204)
	player.body.velocity = Vector2.ZERO
	await ticks(4)
	assert(shell.is_moving_shell() and shell.body.velocity.x == 180)
	assert(GameHandler.player_status.score == score + 500 and not level.death_in_progress)
	assert(shell._active_sound_effect.stream == SoundHandler.get_sound(&"enemy_smack"))
	var paused_position := shell.body.global_position
	assert(GameHandler.request_pause_toggle())
	await ticks(10)
	assert(shell.body.global_position == paused_position)
	assert(GameHandler.request_pause_toggle())
	player.body.global_position = Vector2(40, 100)
	await ticks(40)
	assert(shell.body.velocity.x == -180)
	assert(shell._active_sound_effect.stream == SoundHandler.get_sound(&"bump"))
	shell.body.global_position = Vector2(128, 200)
	shell.get_node("StateMachine/ShellMoving")._direction = 1
	player.body.global_position = Vector2(128, 195)
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
	var survivor_score := GameHandler.player_status.score
	moving._on_enemy_contact(survivor)
	moving._on_enemy_contact(survivor)
	assert(survivor.reactions == 1 and not survivor._defeated)
	assert(GameHandler.player_status.score == survivor_score and shell.shell_chain == 0)
	survivor.free()
	for index in range(9):
		var target := (
			load("res://scenes/entities/enemies/goomba/goomba.tscn").instantiate() as BaseEnemy
		)
		target.position = Vector2(180, 192)
		level.world_objects.add_child(target)
		var before := GameHandler.player_status.score
		var life_before := GameHandler.player_status.lives
		moving._on_enemy_contact(target)
		assert(target._defeated and target.sprite.flip_v)
		moving._on_enemy_contact(target)
		if index < 7:
			assert(GameHandler.player_status.score == before + chain_points[index])
		else:
			assert(GameHandler.player_status.lives == life_before + 1)
		target.free()
	# Moving shell versus idle shell: only the idle target is defeated.
	var retained_chain: int = shell.shell_chain
	assert(shell.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))
	assert(shell.receive_hit(EntityHit.new(player, &"kick", Vector2.ZERO)))
	assert(shell.shell_chain == retained_chain)
	var squashed := (
		load("res://scenes/entities/enemies/goomba/goomba.tscn").instantiate() as BaseEnemy
	)
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
	var before := GameHandler.player_status.score
	moving._on_enemy_contact(target)
	assert(shell._defeated and target._defeated)
	assert(GameHandler.player_status.score == before + 1500)
	moving._on_enemy_contact(target)
	assert(GameHandler.player_status.score == before + 1500)
	game.queue_free()
	await ticks(2)
	# A fresh side overlap with a moving shell damages Mario.
	game = load("res://tests/fixtures/silent_game.tscn").instantiate()
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
	game = load("res://tests/fixtures/silent_game.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	level = GameHandler.current_level
	level.player.body.global_position = Vector2(40, 180)
	shell = koopa(140)
	assert(shell.receive_hit(EntityHit.new(level.player, &"stomp", Vector2.DOWN)))
	var overlap := (
		load("res://scenes/entities/enemies/goomba/goomba.tscn").instantiate() as BaseEnemy
	)
	overlap.position = Vector2(146, 192)
	level.world_objects.add_child(overlap)
	await ticks(2)
	before = GameHandler.player_status.score
	assert(shell.receive_hit(EntityHit.new(level.player, &"kick", Vector2.ZERO)))
	await ticks(2)
	assert(overlap._defeated and shell.is_moving_shell())
	assert(GameHandler.player_status.score == before + 1000)
	await ticks(3)
	assert(GameHandler.player_status.score == before + 1000)
	game.queue_free()
	await ticks(2)
	print("shell_interaction_test: PASS")
	get_tree().quit()
