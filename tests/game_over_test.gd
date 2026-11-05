extends Node


func ticks(count: int = 1) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func wait_idle() -> void:
	for frame in range(900):
		if not GameHandler.transitions.busy:
			return
		await ticks()
	assert(false, "Transition did not finish.")


func wait_phase(phase: StringName) -> void:
	for frame in range(300):
		if GameHandler.transitions.busy and GameHandler.transitions.phase == phase:
			return
		await ticks()
	assert(false, "Presentation phase was not reached.")


func make_game() -> Node:
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	var fixture := game.initial_level.instantiate() as BaseLevel
	fixture.death_sound = null
	fixture.death_fallback_delay = 0.05
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	assert(ResourceSaver.save(packed, "res://.godot/validation/game-over-level.tscn") == OK)
	game.initial_level = load("res://.godot/validation/game-over-level.tscn")
	return game


func begin_final_death() -> void:
	var level := GameHandler.current_level
	GameHandler.set_lives(0)
	assert(level.on_death(level.player))
	assert(GameHandler.player_status.lives == -1)
	await wait_phase(&"game_over")


func _ready() -> void:
	GameHandler.clear_session()
	assert(
		GameHandler.player_status.lives == 2 and GameHandler.player_status.get_display_lives() == 3
	)
	var director: TransitionCoordinator = GameHandler.transitions
	var definition := director.get_definition(&"game_over")
	assert(
		definition.stages[0].minimum_frames == 378 and definition.stages[0].wait_for_presentation
	)
	assert(
		(
			(load("res://assets/transitions/game_over.tres") as Resource).stages[0].minimum_frames
			== 378
		)
	)
	var level_definition := director.get_definition(&"level")
	level_definition.minimum_frames = 1
	for stage in level_definition.stages:
		stage.minimum_frames = 1
	var game := make_game()
	add_child(game)
	game.transitions_enabled = true
	GameHandler.set_top_score(456789)
	GameHandler.set_score(456999)
	GameHandler.set_coins(8)
	var key := GameHandler.current_level._progress_key
	GameHandler.store_area_progress(key, &"probe", {"collected_coins": [Vector2i(1, 1)]})
	for reserves in [1, 0]:
		var level := GameHandler.current_level
		assert(level.on_death(level.player))
		assert(GameHandler.player_status.lives == reserves)
		for frame in range(300):
			await ticks()
			if GameHandler.current_level != level and not director.busy:
				break
		assert(GameHandler.flow == GameHandler.GameFlow.PLAYING)
		assert(GameHandler.get_area_progress(key, &"probe").collected_coins.size() == 1)
	assert(GameHandler.player_status.get_display_lives() == 1)
	await begin_final_death()
	var card := game.get_node("UI/ScreenContainer/TransitionScreen").presentation as Control
	assert(card.get_node("Message").text == "GAME OVER" and not card.has_node("Lives"))
	assert(card.audio.playing and card.audio.volume_db == -8.0)
	assert(not (card.audio.stream as AudioStreamWAV).loop_mode)
	assert(GameHandler.current_level == null)
	assert(GameHandler.get_area_progress(key, &"probe").collected_coins.size() == 1)
	assert(not ControllerHandler.enabled and not game.get_node("LevelContainer").visible)
	assert(game.get_node("UI/HUD").visible and game.get_node("UI/HUD/CoinCount").text == "08")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(
			(
				get_viewport().get_texture().get_image().save_png(
					"res://.godot/validation/game-over.png"
				)
				== OK
			)
		)
	Input.action_press(ControllerHandler.start_action)
	await ticks(3)
	assert(GameHandler.flow == GameHandler.GameFlow.GAME_OVER and director.busy)
	await wait_idle()
	assert(GameHandler.flow == GameHandler.GameFlow.TITLE)
	assert(director.elapsed_frames >= 402)
	assert(GameHandler.current_level.scene_file_path == "res://scenes/levels/test_level.tscn")
	assert(GameHandler.get_area_progress(key, &"probe").is_empty())
	assert(GameHandler.player_status.lives == 2 and GameHandler.top_score == 456999)
	assert(GameHandler.player_status.score == 0 and GameHandler.player_status.coins == 0)
	assert(GameHandler.player_status.powerup_form == PlayerStatus.PowerupForm.SMALL)
	await ticks(3)
	assert(
		GameHandler.flow == GameHandler.GameFlow.TITLE,
		"Held Start must not auto-start the next game."
	)
	Input.action_release(ControllerHandler.start_action)
	await ticks(2)
	Input.action_press(ControllerHandler.start_action)
	await ticks(2)
	Input.action_release(ControllerHandler.start_action)
	await wait_idle()
	assert(GameHandler.flow == GameHandler.GameFlow.PLAYING)
	assert(
		GameHandler.player_status.lives == 2 and GameHandler.player_status.get_display_lives() == 3
	)
	assert(GameHandler.player_status.score == 0 and GameHandler.player_status.coins == 0)
	# Sound completion is an independent gate when minimum timing is short.
	definition.minimum_frames = 1
	definition.stages[0].minimum_frames = 1
	definition.stages[1].minimum_frames = 1
	await begin_final_death()
	await ticks(5)
	assert(director.busy and director.phase == &"game_over")
	await wait_idle()
	assert(GameHandler.flow == GameHandler.GameFlow.TITLE)
	assert(GameHandler.start_new_game())
	await wait_idle()
	# Cancel by replacing the world: no stale completion may show the title over it.
	await begin_final_death()
	assert(GameHandler.load_level(game.initial_level))
	var replacement := GameHandler.current_level
	await ticks(3)
	assert(GameHandler.flow == GameHandler.GameFlow.PLAYING and not director.busy)
	assert(GameHandler.current_level == replacement and not replacement.transition_in_progress)
	assert(not replacement.player.gameplay_suspended)
	# Missing audio still completes through the minimum-frame path.
	var silent_card: Control = load("res://scenes/ui/transitions/game_over.tscn").instantiate()
	silent_card.sound = null
	var silent_scene := PackedScene.new()
	assert(silent_scene.pack(silent_card) == OK)
	silent_card.free()
	definition.stages[0].scene = silent_scene
	await begin_final_death()
	await wait_idle()
	assert(GameHandler.flow == GameHandler.GameFlow.TITLE)
	assert(GameHandler.start_new_game())
	await wait_idle()
	# An unfinished presentation is bounded and still recovers to a usable title.
	definition.stages[0].scene = load("res://tests/fixtures/pending_presentation.tscn")
	definition.stages[0].completion_timeout_frames = 5
	await begin_final_death()
	await wait_idle()
	assert(GameHandler.flow == GameHandler.GameFlow.TITLE and director.elapsed_frames >= 6)
	assert(GameHandler.start_new_game())
	await wait_idle()
	definition.stages[0].completion_timeout_frames = 600
	# A closing Game cancels the card/audio and cannot recreate a title afterward.
	definition.stages[0].scene = load("res://scenes/ui/transitions/game_over.tscn")
	await begin_final_death()
	game.free()
	await ticks(3)
	assert(GameHandler.current_game == null and GameHandler.flow == GameHandler.GameFlow.DETACHED)
	assert(not director.busy and not GameHandler._area_progress.is_empty())
	print(
		"PASS: three attempts, negative-only game over, reference hold, sound completion/fallback, title-owned progress cleanup, title/input reset and stale/cancelled ownership"
	)
	get_tree().quit()
