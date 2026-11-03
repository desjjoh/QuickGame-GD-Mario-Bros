extends Node

signal physics_step_finished
func _physics_process(_delta: float) -> void:
	physics_step_finished.emit()
func ticks(count: int) -> void:
	for frame in range(count):
		await physics_step_finished

func make_game() -> Node:
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	game.transitions_enabled = false
	var fixture := load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	fixture.death_fallback_delay = 0.05
	fixture.death_sound = null
	var main := fixture.get_node("Areas/MainArea") as BaseLevelArea
	var markers := main.get_node("Layouts/EntityLayout") as TileMapLayer
	markers.clear()
	markers.set_cell(Vector2i(4,9),1,Vector2i.ZERO)
	var floor := main.get_node("Layouts/GroundLayout") as TileMapLayer
	floor.clear()
	for x in range(60):
		floor.set_cell(Vector2i(x,13),0,Vector2i.ZERO)
	fixture.get_node("Players/PlayerSpawn").position = Vector2(48,208)
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area,true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	assert(ResourceSaver.save(packed,"res://.godot/validation/death-fixture.tscn") == OK)
	game.initial_level = ResourceLoader.load("res://.godot/validation/death-fixture.tscn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	return game

func _ready() -> void:
	process_physics_priority = 200
	for reset in [false,true]:
		GameHandler.clear_session()
		GameHandler.reset_progress_on_death = reset
		GameHandler.set_session_value(&"lives",3)
		var game := make_game()
		add_child(game)
		await ticks(3)
		var level := GameHandler.current_level
		var player := level.player
		var block := level.world_objects.get_node("question_block_4_9") as BaseBlock
		assert(block.receive_hit(EntityHit.new(null,&"bonk",Vector2.UP)))
		for frame in range(30): block.state_machine.process_physics(1.0/60.0)
		assert(block.state_machine.current_state.name == &"Inactive")
		# Save an inactive-area edit too; death reset must cover the whole level.
		assert(level.request_area_transfer(&"lower"))
		await ticks(2)
		var lower_floor := level.active_area.get_node("Layouts/GroundLayout") as TileMapLayer
		lower_floor.set_cell(Vector2i(2,2),0,Vector2i.ZERO)
		assert(level.request_area_transfer(&"main"))
		await ticks(2)
		player = level.player
		block = level.world_objects.get_node("question_block_4_9") as BaseBlock
		var camera := get_viewport().get_camera_2d()
		var camera_position := camera.global_position
		# Partial visibility and the first two tiles below disappearance are safe.
		player.body.global_position = Vector2(48,245)
		level._check_fall_death()
		assert(not level.death_in_progress)
		for safe_y in [260.0,287.0,288.0]:
			player.body.global_position.y = safe_y
			level._check_fall_death()
			assert(not level.death_in_progress)
		player.body.global_position.y = 289.0
		var old_player: WeakRef = weakref(player)
		level._check_fall_death()
		assert(level.death_in_progress and level.player == null and player.is_shutdown)
		assert(player.state_machine.current_state == null)
		assert(not ControllerHandler.input_received.is_connected(player.state_machine.process_input))
		assert(not level.on_death(player))
		assert(not level.request_area_transfer(&"lower"))
		assert(block.gameplay_suspended and not block.is_physics_processing())
		assert(not block.receive_hit(EntityHit.new(null,&"bonk",Vector2.UP)))
		assert(camera.global_position == camera_position)
		for frame in range(12):
			await ticks(1)
			if GameHandler.current_level != level: break
		assert(GameHandler.current_level != level)
		assert(old_player.get_ref() == null)
		var fresh := GameHandler.current_level
		assert(fresh.player.body.global_position.distance_to(fresh.player_spawn.global_position) < 0.2)
		assert(fresh.active_area.area_id == &"main")
		var fresh_block := fresh.world_objects.get_node("question_block_4_9") as BaseBlock
		assert(fresh_block.state_machine.current_state.name == (&"Active" if reset else &"Inactive"))
		assert(GameHandler.get_session_value(&"lives") == 3)
		assert(fresh.request_area_transfer(&"lower"))
		await ticks(2)
		assert((fresh.active_area.get_node("Layouts/GroundLayout") as TileMapLayer).get_cell_source_id(Vector2i(2,2)) == (-1 if reset else 0))
		game.free()
		await get_tree().process_frame
	# LowerArea uses its own world-space viewport bottom, then restarts in MainArea.
	var lower_game := make_game()
	add_child(lower_game)
	var lower_level := GameHandler.current_level
	assert(lower_level.request_area_transfer(&"lower"))
	await ticks(2)
	var lower_camera := get_viewport().get_camera_2d()
	var bottom := lower_camera.global_position.y + get_viewport().get_visible_rect().size.y / lower_camera.zoom.y / 2.0
	lower_level.player.body.global_position.y = bottom + 5.0
	lower_level._check_fall_death()
	assert(not lower_level.death_in_progress)
	lower_level.player.body.global_position.y = bottom + 48.0
	lower_level._check_fall_death()
	assert(not lower_level.death_in_progress)
	lower_level.player.body.global_position.y = bottom + 49.0
	lower_level._check_fall_death()
	assert(lower_level.death_in_progress)
	for frame in range(12):
		await ticks(1)
		if GameHandler.current_level != lower_level: break
	assert(GameHandler.current_level != lower_level and GameHandler.current_level.active_area.area_id == &"main")
	lower_game.free()
	await get_tree().process_frame
	GameHandler.reset_progress_on_death = false
	GameHandler.clear_session()
	# Reversible suspension gates gameplay, but animation advances independently.
	var question := load("res://scenes/entities/blocks/question/question_block.tscn").instantiate() as BaseBlock
	add_child(question)
	question.set_gameplay_suspended(true)
	var state := question.state_machine.current_state
	question.state_machine.change_state(question.state_machine.get_state(&"Inactive"))
	assert(question.state_machine.current_state == state)
	question.animation_player.seek(0.0,true)
	await ticks(30)
	var phase := (question.get_node("Presentation/PaletteAnimation").cycle as CosmeticAnimationCycle).phase_at(GameHandler.animation_clock.tick_count)
	assert(question.sprite.texture.resource_path.ends_with(["question-block.png","question-block-2.png","question-block-3.png","question-block-2.png"][phase]))
	question.set_gameplay_suspended(false)
	assert(not question.gameplay_suspended and question.is_physics_processing())
	question.free()
	# Optional visible presentation is retained until explicit completion.
	var player := load("res://scenes/player/mario (small)/mario.tscn").instantiate() as BasePlayer
	var death_state := load("res://tests/fixtures/death_presentation_state.gd").new() as PlayerState
	death_state.name = "Death"
	player.get_node("StateMachine").add_child(death_state)
	player.death_state = death_state
	add_child(player)
	player.begin_death(true)
	assert(player.is_dead and not player.is_shutdown and player.state_machine.current_state == death_state)
	assert(not death_state.controls_enabled)
	await ticks(2)
	assert(death_state.ticks > 0)
	player.finish_death()
	player.shutdown()
	player.free()
	# Actual supplied audio stays level-owned after the player is removed.
	var game := make_game()
	add_child(game)
	var level := GameHandler.current_level
	level.death_sound = load("res://assets/soundtrack/smb_mariodie.wav")
	assert(level.on_death(level.player))
	assert(level._death_audio.playing and level._death_audio.get_parent() == level)
	assert((level._death_audio.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED)
	var playback := level._death_audio.stream.instantiate_playback()
	playback.start()
	var amplitude := 0.0
	for sample in playback.mix_audio(1.0,44100): amplitude = maxf(amplitude,maxf(absf(sample.x),absf(sample.y)))
	assert(amplitude > 0.01)
	playback.stop()
	playback = null
	await ticks(2)
	assert(GameHandler.current_level == level)
	# The actual jingle must complete before restart, without relying on a fixed guessed delay.
	var maximum_ticks := ceili(level.death_sound.get_length() * 60.0) + 90
	for frame in range(maximum_ticks):
		await ticks(1)
		if GameHandler.current_level != level: break
	assert(GameHandler.current_level != level)
	level = GameHandler.current_level
	level.death_sound = null
	level.death_fallback_delay = 5.0
	assert(level.on_death(level.player))
	# Stale completion cannot replace another level or clear its progress.
	assert(GameHandler.load_level(game.initial_level))
	var replacement := GameHandler.current_level
	level._restart_after_death()
	assert(GameHandler.current_level == replacement)
	game.free()
	await get_tree().process_frame
	await ticks(8)
	print("PASS: pit threshold, player cleanup, world suspension/animation, optional presentation, death audio, global preserve/reset across areas, spawn restart, unchanged lives and stale completion.")
	get_tree().quit()
