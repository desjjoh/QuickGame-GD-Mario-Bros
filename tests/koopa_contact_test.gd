extends Node


func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func make_game() -> Node:
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	return game


func spawn_koopa(level: BaseLevel, koopa_scene: PackedScene) -> BaseEnemy:
	var koopa := koopa_scene.instantiate() as BaseEnemy
	koopa.position = Vector2(144, 192)
	assert(level.try_claim_spawn_slot(&"enemy", koopa))
	level.world_objects.add_child(koopa)
	return koopa


func _ready() -> void:
	var game := make_game()
	var level: BaseLevel = GameHandler.current_level
	var koopa_scene := load("res://scenes/entities/enemies/koopa/green_koopa.tscn") as PackedScene
	var koopa := spawn_koopa(level, koopa_scene)
	var player := level.player
	player.set_physics_process(false)
	player.body.global_position = Vector2(150, 198)
	player.body.velocity = Vector2(90, 120)
	var lives := GameHandler.player_status.lives
	var score := GameHandler.player_status.score
	var defeats: Array[EntityHit] = []
	koopa.defeated.connect(func(hit: EntityHit): defeats.append(hit))
	for frame in range(6):
		await ticks(1)
		if koopa.state_machine.current_state.name == &"ShellIdle":
			break
	assert(koopa.state_machine.current_state.name == &"ShellIdle")
	assert(player.body.global_position == Vector2(150, 198))
	assert(player.body.velocity == Vector2(90, -240))
	assert(player._active_sound_effect.stream == SoundHandler.get_sound(&"stomp"))
	assert(GameHandler.player_status.lives == lives and not level.death_in_progress)
	assert(not koopa._defeated and defeats.is_empty())
	assert(level.spawn_registry._live_spawns[&"enemy"].has(koopa))
	assert(koopa.sprite.vframes == 2 and koopa.sprite.frame == 4)
	assert(koopa.sprite.position == Vector2(0, 2))
	assert(not koopa.get_node("Presentation/WalkAnimationSync").enabled)
	assert(not koopa.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))
	var shell_position := koopa.body.global_position
	assert(GameHandler.request_pause_toggle())
	await ticks(10)
	assert(koopa.body.global_position == shell_position)
	assert(koopa.sprite.frame == 4)
	assert(GameHandler.request_pause_toggle())
	player.body.global_position = koopa.body.global_position + Vector2(0, 4)
	player.body.velocity = Vector2.ZERO
	await ticks(35)
	assert(not level.death_in_progress and GameHandler.player_status.lives == lives)
	assert(koopa.body.velocity.x == 0 and koopa.body.is_on_floor())
	assert(koopa.body.global_position.x == shell_position.x)
	assert(GameHandler.player_status.score == score + 100 and defeats.is_empty())
	koopa.body.global_position = Vector2(128, 100)
	koopa.body.velocity = Vector2.ZERO
	await ticks(10)
	assert(koopa.body.global_position.y > 100)
	assert(koopa.body.velocity.x == 0 and koopa.body.velocity.y > 0)
	# Shell uses the same themed sheet and fixed contact box in every theme.
	for theme in ["overworld", "underground", "castle"]:
		var themed := koopa_scene.instantiate() as BaseEnemy
		themed.visual_theme = load("res://assets/themes/%s.tres" % theme)
		themed.position = Vector2(210, 100)
		level.world_objects.add_child(themed)
		assert(themed.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))
		assert(
			(
				themed.sprite.texture.resource_path
				== "res://assets/palettes/%s/enemies/koopa.png" % theme
			)
		)
		assert(themed._player_contact_shape.shape.size == Vector2(10, 6))
		assert(themed._player_contact_area.position == Vector2(0, 1))
		themed.queue_free()
	game.queue_free()
	await ticks(2)
	# Walking side contact follows the existing player-death path once.
	game = make_game()
	level = GameHandler.current_level
	koopa = spawn_koopa(level, koopa_scene)
	koopa.set_physics_process(false)
	player = level.player
	player.set_physics_process(false)
	player.body.global_position = koopa.body.global_position + Vector2(-12, 4)
	player.body.velocity = Vector2.ZERO
	lives = GameHandler.player_status.lives
	await ticks(2)
	await get_tree().physics_frame
	if Engine.get_physics_frames() % 2 == 0:
		await get_tree().physics_frame
	player.body.global_position.x += 1.0
	assert(koopa._touches_player_now(player))
	koopa._check_normal_player_contact(player)
	assert(not player.is_dead, "An odd-tick contact must wait for the next eligible tick.")
	player.body.global_position.x -= 1.0
	await get_tree().physics_frame
	player.body.global_position.x += 1.0
	koopa._physics_process(1.0 / 60.0)
	assert(level.death_in_progress and player.is_dead)
	assert(GameHandler.player_status.lives == lives - 1)
	assert(koopa.state_machine.current_state.name == &"Walking")
	game.queue_free()
	await ticks(2)
	print("koopa_contact_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
