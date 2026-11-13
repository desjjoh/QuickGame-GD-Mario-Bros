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
	_check_rescue_reset()
	await _check_rescue(false)
	await _check_rescue(true)
	await _check_rescue(false, true)
	await _check_rescue(true, true)
	print("castle_rescue_test: PASS")
	await FINISH.finish(get_tree())


func _check_rescue_reset() -> void:
	var rescue := (
		preload("res://scenes/levels/endings/castle_rescue.tscn").instantiate() as CastleRescue
	)
	add_child(rescue)
	var greeting := rescue.get_node("Messages/Thanks") as Label
	var message := rescue.get_node("Messages/RescueMessage") as Label
	for tick in range(131):
		assert(not rescue.advance(GameHandler.PlayerCharacter.LUIGI))
	assert(greeting.visible and greeting.text == "THANK YOU LUIGI!" and message.visible)
	rescue.reset()
	assert(rescue.elapsed_ticks == 0)
	assert(not greeting.visible and not message.visible)
	for tick in range(3):
		assert(not rescue.advance(GameHandler.PlayerCharacter.MARIO))
	assert(greeting.visible and greeting.text == "THANK YOU MARIO!" and not message.visible)
	rescue.free()


func _check_rescue(luigi: bool, alternate_layout := false) -> void:
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
	var rescue := objects.get_node("CastleRescue") as CastleRescue
	var stop := rescue.player_stop
	var toad := rescue.get_node("Toad") as Sprite2D
	var thanks := rescue.get_node("Messages/Thanks") as Label
	var message := rescue.get_node("Messages/RescueMessage") as Label
	assert(toad.visible and toad.texture.resource_path == "res://assets/items/toad.png")
	assert(not thanks.visible and not message.visible)

	var bridge := objects.get_node("CastleBridge") as CastleBridge
	var axe := bridge.axe
	var deck := bridge.get_node("Deck") as TileMapLayer
	var chain := bridge.get_node("Chain") as Sprite2D
	var area := level.active_area
	if alternate_layout:
		bridge.position.x += 16.0
		rescue.position.x -= 16.0
		stop.position.x += 8.0
		for column in range(4):
			deck.erase_cell(Vector2i(column, 0))
		assert(deck.get_used_cells().size() == 9)
		area.get_node(ending.lift_spawner_path).free()
		ending.lift_spawner_path = NodePath()
		ending.approach_camera_left += 16.0
		ending.rescue_camera_left -= 16.0
		ending.bind_area(area)
	var deck_cells := deck.get_used_cells()
	deck_cells.sort()
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
	var lift_spawner := area.get_node_or_null(ending.lift_spawner_path)
	assert(lift_spawner == null if alternate_layout else lift_spawner.get_child_count() > 1)
	var live_boss := alternate_layout and not luigi
	if luigi:
		for shot in range(5):
			assert(boss.receive_hit(EntityHit.new(player, &"fireball", Vector2.RIGHT)))
		assert(boss.is_defeated())
		collapse_cues.clear()
	elif live_boss:
		boss.set_physics_process(false)
		boss.body.global_position.y = area.to_global(Vector2(0, 128)).y
		boss._vertical.position_fraction = 0
		boss._feet_ticks = 18
	else:
		boss.free()
	var area_music := MusicHandler._voice.stream
	var remaining_time := GameHandler.time_remaining
	assert(area_music == MusicHandler._loops[MusicHandler.Track.CASTLE])
	var contact_x := player.body.global_position.x
	var camera_x := camera.global_position.x
	if alternate_layout:
		var width := camera.get_viewport_rect().size.x / camera.zoom.x
		assert(
			is_equal_approx(
				area.to_local(camera.global_position).x - width / 2.0, ending.approach_camera_left
			)
		)
	axe.touch(player)
	if not alternate_layout:
		assert(lift_spawner.is_queued_for_deletion() and not lift_spawner.visible)
	assert(not axe.visible and ending.phase == CastleEndingPresentation.Phase.HOLD)
	var walk_tick := 124 if live_boss else 3
	for tick in range(1, walk_tick):
		await stepped
		assert(ending.phase == CastleEndingPresentation.Phase.HOLD)
		assert(player.body.global_position.x == contact_x)
		assert(camera.global_position.x == camera_x and camera.is_scroll_locked())
		if live_boss and tick < walk_tick - 2:
			assert(MusicHandler._voice.stream == area_music and MusicHandler._voice.playing)
		else:
			assert(not MusicHandler._voice.playing)
		if live_boss and tick >= 18 and tick <= 58 and (tick - 18) % 4 == 0:
			assert(collapse_cues.size() == 1 + ((tick - 18) >> 2))
			var cue := &"bowser_fall" if tick == 58 else &"fireworks"
			assert(collapse_cues.back() == SoundHandler.get_sound(cue))
			assert(shatter.playing and shatter.stream == SoundHandler.get_sound(&"brick_shatter"))
			assert(deck.get_used_cells().size() == mini(9, (58 - tick) >> 2))
			assert(chain.visible == (tick == 18))
			for column in range(4, 13):
				assert(
					(
						(deck.get_cell_source_id(Vector2i(column, 0)) != -1)
						== (column < 4 + mini(9, (58 - tick) >> 2))
					)
				)
	await stepped
	assert(ending.phase == CastleEndingPresentation.Phase.WALK)
	assert(is_equal_approx(player.body.global_position.x, contact_x + 1.5))
	assert(camera.global_position.x == camera_x + 1.0 and not camera.is_scroll_locked())
	assert(MusicHandler._voice.stream == MusicHandler.CASTLE_CLEAR_CUE)
	assert(MusicHandler._voice.playing and MusicHandler._voice.pitch_scale == 1.0)
	assert(MusicHandler._voice.volume_db == 0.0)
	assert(is_equal_approx(MusicHandler.CASTLE_CLEAR_CUE.get_length(), 364.0 / 60.0))

	for tick in range(240):
		if ending.phase == CastleEndingPresentation.Phase.AT_RESCUE:
			break
		await stepped
		assert(not thanks.visible and not message.visible)
	assert(ending.phase == CastleEndingPresentation.Phase.AT_RESCUE)
	if live_boss:
		assert(deck.get_used_cells().is_empty() and not chain.visible and bridge.collapse_complete)
		assert(collapse_events.size() == 1 and collapse_cues.size() == 11)
	else:
		var remaining_cells := deck.get_used_cells()
		remaining_cells.sort()
		assert(remaining_cells == deck_cells, "The skipped collapse changed the deck cells.")
		assert(chain.visible and not bridge.collapse_complete)
		assert(collapse_events.is_empty() and collapse_cues.is_empty() and shatter.stream == null)
	var half_width := camera.get_viewport_rect().size.x / (2.0 * camera.zoom.x)
	assert(
		is_equal_approx(
			area.to_local(camera.global_position).x - half_width, ending.rescue_camera_left
		)
	)
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
			assert(rescue.elapsed_ticks == 131)
			get_tree().paused = false
	await stepped
	await stepped
	assert(GameHandler.current_level.scene_file_path == NEXT.resource_path)
	assert(GameHandler.flow == GameHandler.GameFlow.PLAYING)
	game.free()
	await stepped
