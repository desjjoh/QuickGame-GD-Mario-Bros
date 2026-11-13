extends Node

const LEVEL := preload("res://scenes/levels/worlds/world 1/1-4.tscn")
const NEXT := preload("res://tests/fixtures/silent_level.tscn")
const GAME := preload("res://tests/fixtures/silent_game.tscn")
const FINISH := preload("res://tests/fixtures/finish_test.gd")

signal stepped


func _physics_process(_delta: float) -> void:
	stepped.emit()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 200
	await _check_rescue(false)
	await _check_rescue(true)
	print("castle_rescue_test: PASS")
	await FINISH.finish(get_tree())


func _check_rescue(luigi: bool) -> void:
	var game := GAME.instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.stages.assign([LEVEL, NEXT])
	add_child(game)
	if luigi:
		GameHandler.player_character = GameHandler.PlayerCharacter.LUIGI
		assert(GameHandler.load_level(LEVEL))
	var level := GameHandler.current_level
	var ending := level.ending_presentation as CastleEndingPresentation
	var player := level.player as Mario
	assert((player.scene_file_path.contains("/luigi/")) == luigi)
	var objects := level.world_objects
	var rescue := objects.get_node("CastleRescue") as Node2D
	var stop := rescue.get_node("PlayerStop") as Marker2D
	var toad := rescue.get_node("Toad") as Sprite2D
	var thanks := rescue.get_node("Messages/Thanks") as Label
	var message := rescue.get_node("Messages/RescueMessage") as Label
	assert(toad.visible and toad.texture.resource_path == "res://assets/items/toad.png")
	assert(level.active_area.to_local(toad.global_position) == Vector2(2448, 176))
	assert(level.active_area.to_local(stop.global_position) == Vector2(2436, 208))
	assert(not thanks.visible and not message.visible)

	var bridge := objects.get_node("CastleBridge") as CastleBridge
	var axe := bridge.axe
	var deck := bridge.get_node("Deck") as TileMapLayer
	var chain := bridge.get_node("Chain") as Sprite2D
	var deck_cells := deck.tile_map_data
	var shatter := ending.get_node("CollapseShatter") as AudioStreamPlayer
	var collapse_events: Array[bool] = []
	bridge.collapse_finished.connect(func() -> void: collapse_events.append(true))
	var collapse_cues: Array[AudioStream] = []
	var record_cue := func(occupied: bool) -> void:
		if occupied:
			collapse_cues.append(SoundHandler._square_two.stream)
	SoundHandler.reward_voice_changed.connect(record_cue)
	var camera := level.active_area.get_node("Camera2D") as LevelCamera
	player.body.global_position = axe.global_position + Vector2(9, 0)
	camera.follow_target(player.body)
	level.active_area.update_camera_activity()
	var boss := level.active_area.get_node(ending.boss_path) as Bowser
	var lift_spawner := level.active_area.get_node(ending.lift_spawner_path)
	assert(lift_spawner.get_child_count() > 1)
	if luigi:
		for shot in range(5):
			assert(boss.receive_hit(EntityHit.new(player, &"fireball", Vector2.RIGHT)))
		assert(boss.is_defeated())
		collapse_cues.clear()
	else:
		boss.free()
	var area_music := MusicHandler._voice.stream
	var remaining_time := GameHandler.time_remaining
	assert(area_music == MusicHandler._loops[MusicHandler.Track.CASTLE])
	var contact_x := player.body.global_position.x
	var camera_x := camera.global_position.x
	axe.touch(player)
	assert(lift_spawner.is_queued_for_deletion() and not lift_spawner.visible)
	assert(not axe.visible and ending.phase == CastleEndingPresentation.Phase.HOLD)
	for tick in range(2):
		await stepped
		assert(ending.phase == CastleEndingPresentation.Phase.HOLD)
		assert(player.body.global_position.x == contact_x)
		assert(camera.global_position.x == camera_x and camera.is_scroll_locked())
		assert(not MusicHandler._voice.playing)
	await stepped
	assert(ending.phase == CastleEndingPresentation.Phase.WALK)
	assert(is_equal_approx(player.body.global_position.x, contact_x + 1.5))
	assert(camera.global_position.x == camera_x + 1.0 and not camera.is_scroll_locked())
	assert(MusicHandler._voice.stream == MusicHandler.CASTLE_CLEAR_CUE)
	assert(MusicHandler._voice.playing and MusicHandler._voice.pitch_scale == 1.0)
	assert(MusicHandler._voice.volume_db == 0.0)
	assert(is_equal_approx(MusicHandler.CASTLE_CLEAR_CUE.get_length(), 364.0 / 60.0))

	for tick in range(187):
		await stepped
		assert(not thanks.visible and not message.visible)
	assert(ending.phase == CastleEndingPresentation.Phase.AT_RESCUE)
	assert(deck.tile_map_data == deck_cells and chain.visible and not bridge.collapse_complete)
	assert(collapse_events.is_empty() and collapse_cues.is_empty() and shatter.stream == null)
	SoundHandler.reward_voice_changed.disconnect(record_cue)
	assert(player.body.global_position == stop.global_position)
	assert(player.state_machine.current_state is MarioIdleState)
	assert(player.sprite.texture == player.form_controller.current_form.idle)

	for tick in range(1, 382):
		await stepped
		assert(thanks.visible == (tick >= 3))
		assert(message.visible == (tick >= 131))
		assert(player.body.global_position == stop.global_position)
		assert(GameHandler.time_remaining == remaining_time)
		if tick == 3:
			assert(thanks.text == ("THANK YOU LUIGI!" if luigi else "THANK YOU MARIO!"))
		if tick == 131:
			assert(message.text == "BUT OUR PRINCESS IS IN\nANOTHER CASTLE!")
			get_tree().paused = true
			await stepped
			await stepped
			assert(ending._rescue_ticks == 131)
			get_tree().paused = false
	await stepped
	await stepped
	assert(GameHandler.current_level.scene_file_path == NEXT.resource_path)
	assert(GameHandler.flow == GameHandler.GameFlow.PLAYING)
	game.free()
	await stepped
