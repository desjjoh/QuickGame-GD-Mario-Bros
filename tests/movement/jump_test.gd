extends Node


func _ready() -> void:
	call_deferred("run_checks")


func tick(count: int) -> void:
	for index in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame


func trial(game_scene: PackedScene, hold_ticks: int, weight: float) -> float:
	var game: Node = game_scene.instantiate()
	get_tree().root.add_child(game)
	var player := GameHandler.current_player
	player.motion_values.base_weight = weight
	await tick(5)
	assert(player.body.is_on_floor())
	var origin := player.body.global_position.y
	var peak := origin
	Input.action_press(ControllerHandler.primary_action)
	for index in range(110):
		if index == hold_ticks:
			Input.action_release(ControllerHandler.primary_action)
		await tick(1)
		peak = minf(peak, player.body.global_position.y)
		if player.jump_action.active:
			assert(
				player.state_machine.current_state is MarioJumpState,
				"A deliberate jump keeps its state through ascent and descent until landing."
			)
		if index == 3:
			assert(player.state_machine.current_state is MarioJumpState)
			assert(player.sprite.texture.resource_path.ends_with("mario-small-air.tres"))
	assert(player.body.is_on_floor())
	assert(player.state_machine.current_state is MarioIdleState)
	assert(not player.jump_action.active)
	assert(player.jump_action.falling_gravity == 1575.0)
	assert(player.motion_values.gravity == player.motion_values.base_gravity)
	Input.action_release(ControllerHandler.primary_action)
	game.free()
	return origin - peak


func run_checks() -> void:
	var game_scene := load("res://tests/fixtures/silent_game.tscn") as PackedScene
	var short_height := await trial(game_scene, 3, 1.0)
	var tall_height := await trial(game_scene, 90, 1.0)
	var heavy_height := await trial(game_scene, 90, 2.0)
	assert(tall_height > short_height + 10.0)
	assert(heavy_height < tall_height)
	var game: Node = game_scene.instantiate()
	get_tree().root.add_child(game)
	var player := GameHandler.current_player
	await tick(5)
	for speed in [0.0, 33.75, 60.0, 93.75, 105.0]:
		player.body.velocity = Vector2(speed, 0)
		assert(player.jump_action.begin(player.motion_values))
		assert(player.body.velocity.y == (-300.0 if speed >= 93.75 else -240.0))
		player.jump_action.end(player.motion_values)
	player.body.velocity = Vector2.ZERO
	# Exercise falling beyond the test floor independently of camera confinement.
	GameHandler.current_level.keep_player_on_screen = false
	player.body.global_position.x = 300
	# This test creates its own ledge now that the playable floor is wider.
	var ledge_floor := (
		GameHandler.current_level.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
	)
	for x in range(17, 21):
		ledge_floor.erase_cell(Vector2i(x, 13))
		ledge_floor.erase_cell(Vector2i(x, 14))
	await tick(5)
	assert(player.state_machine.current_state is MarioMoveState)
	assert(player.body.velocity.y > 0.0 and not player.jump_action.active)
	assert(not player.jump_action.begin(player.motion_values))
	game.free()
	game = game_scene.instantiate()
	get_tree().root.add_child(game)
	player = GameHandler.current_player
	var ground: TileMapLayer = GameHandler.current_level.get_node(
		"Areas/MainArea/Layouts/GroundLayout"
	)
	ground.set_cell(Vector2i(2, 9), 0, Vector2i.ZERO)
	player.body.global_position.x = 40.0
	await tick(5)
	Input.action_press(ControllerHandler.primary_action)
	var hit_ceiling := false
	var bump_sounds: Array[AudioStream] = []
	player.body.child_entered_tree.connect(
		func(child: Node) -> void:
			if child is AudioStreamPlayer and child.stream == SoundHandler.get_sound(&"bump"):
				bump_sounds.append(child.stream)
	)
	for index in range(60):
		await tick(1)
		if player.body.is_on_ceiling() and not hit_ceiling:
			assert(is_equal_approx(player.body.velocity.y, 3.75))
			assert(player.motion_values.gravity == player.jump_action.falling_gravities[0])
		hit_ceiling = hit_ceiling or player.body.is_on_ceiling()
		assert(player.body.global_position.y >= 173.8)
	Input.action_release(ControllerHandler.primary_action)
	assert(hit_ceiling and player.body.is_on_floor())
	assert(bump_sounds.size() == 1)
	var bump := bump_sounds[0] as AudioStreamWAV
	assert(bump.loop_mode == AudioStreamWAV.LOOP_DISABLED)
	var playback := bump.instantiate_playback()
	playback.start(0.0)
	var peak := 0.0
	for sample in playback.mix_audio(1.0, 30000):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	playback.stop()
	assert(peak > 0.05)
	playback = null
	bump = null
	bump_sounds.clear()
	game.free()
	print(
		(
			"PASS: variable jump heights %s/%s, weight-scaled height %s, landing, air pose, modifier cleanup, ledge fall, and no air jump."
			% [short_height, tall_height, heavy_height]
		)
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
