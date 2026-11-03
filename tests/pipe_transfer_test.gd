extends Node


func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
	var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	var main := fixture.get_node("Areas/MainArea") as BaseLevelArea
	var markers := main.get_node("Layouts/EntityLayout") as TileMapLayer
	markers.clear()
	markers.set_cell(Vector2i(6,12),3,Vector2i.ZERO)
	var floor := main.get_node("Layouts/GroundLayout") as TileMapLayer
	floor.clear()
	for x in range(16):
		floor.set_cell(Vector2i(x,13),0,Vector2i.ZERO)
	fixture.get_node("Areas/LowerArea/Layouts/EntityLayout").clear()
	fixture.get_node("Players/PlayerSpawn").position = Vector2(112,192)
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area,true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	game.initial_level = packed
	add_child(game)
	var level := GameHandler.current_level
	var player := level.player
	var main_area := level.active_area
	var lower := level.get_node("Areas/LowerArea") as BaseLevelArea
	var pipe := main_area.get_node("WorldObjects/pipe_entrance_6_12") as PipeEntrance
	assert(pipe != null)
	var shape := pipe.get_node("Body/CollisionShape2D") as CollisionShape2D
	assert((shape.shape as RectangleShape2D).size == Vector2(32,32))
	assert(shape.position == Vector2(16,16))
	var visuals := pipe.get_node("Visuals") as Node2D
	assert(visuals.get_child_count() == 4)
	assert(visuals.global_position == pipe.global_position)
	assert(level.players.get_index() > level.get_node("Areas").get_index())
	assert(visuals.get_parent() == pipe)
	assert(visuals.z_index == 0)
	var source := (main_area.get_node("Layouts/EntityLayout") as TileMapLayer).tile_set.get_source(3) as TileSetAtlasSource
	assert(source.get_tile_size_in_atlas(Vector2i.ZERO) == Vector2i(2,2))
	assert(source.get_tile_data(Vector2i.ZERO,0).texture_origin == Vector2i(-8,-8))
	GameHandler.set_session_value(&"coins",7)
	await ticks(5)
	assert(player.body.is_on_floor())
	assert(level.active_area == main_area, "Standing on a pipe alone must not teleport.")
	# Down away from the center must not activate it.
	player.body.global_position.x = 103
	player.body.reset_physics_interpolation()
	Input.action_press(ControllerHandler.down_action)
	await ticks(4)
	assert(level.active_area == main_area)
	Input.action_release(ControllerHandler.down_action)
	# Airborne players cannot enter even when aligned and holding Down.
	player.body.global_position = Vector2(112,170)
	player.body.velocity = Vector2(0,-30)
	Input.action_press(ControllerHandler.down_action)
	await ticks(3)
	assert(level.active_area == main_area)
	Input.action_release(ControllerHandler.down_action)
	player.body.global_position = Vector2(112,192)
	player.body.velocity = Vector2.ZERO
	await ticks(5)
	assert(player.body.is_on_floor())
	player.set_physics_process(false)
	level.set_physics_process(false)
	pipe.set_physics_process(false)
	ControllerHandler.input_down = 1
	for directions in [Vector2(1,0), Vector2(0,1), Vector2(1,1)]:
		ControllerHandler.input_left = directions.x
		ControllerHandler.input_right = directions.y
		pipe._physics_process(1.0/60.0)
		assert(not pipe.can_start_entry(player))
		assert(not level.request_pipe_entry(pipe))
		assert(player.state_machine.current_state != player.pipe_enter_state)
	ControllerHandler.input_left = 0
	ControllerHandler.input_right = 0
	# Momentum alone is allowed once horizontal buttons are released.
	player.body.velocity.x = 45
	assert(pipe.can_start_entry(player))
	player.body.velocity = Vector2.ZERO
	var state := player.state_machine.current_state as PlayerState
	state.controls_enabled = false
	ControllerHandler.input_down = 1
	pipe._physics_process(1.0/60.0)
	await get_tree().process_frame
	assert(level.active_area == main_area)
	state.controls_enabled = true
	ControllerHandler.input_down = 1
	assert(not level.request_area_transfer(&"missing"))
	assert(not level.request_area_transfer(&"main"))
	pipe._physics_process(1.0/60.0)
	assert(not level.request_area_transfer(&"lower"), "Only one transfer may be queued.")
	assert(player.state_machine.current_state is PlayerPipeEnterState)
	assert(level.players.get_index() < level.get_node("Areas").get_index())
	assert(not (player.state_machine.current_state as PlayerState).controls_enabled)
	assert(player.body.collision_layer == 0 and player.body.collision_mask == 0)
	var entry_origin := player.body.global_position
	var source_camera_position: Vector2 = main_area.get_node("Camera2D").global_position
	var pipe_sounds := player.body.find_children("*", "AudioStreamPlayer2D", true, false)
	assert(pipe_sounds.size() == 1)
	var sound := pipe_sounds[0] as AudioStreamPlayer2D
	assert(sound.stream == player.pipe_enter_state.enter_sound_effect)
	assert((sound.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED)
	var playback := sound.stream.instantiate_playback()
	playback.start(0.0)
	var amplitude := 0.0
	for sample in playback.mix_audio(1.0, 22050):
		amplitude = maxf(amplitude, maxf(absf(sample.x),absf(sample.y)))
	playback.stop()
	assert(amplitude > 0.05)
	playback = null
	for tick in range(24):
		player.state_machine.process_physics(1.0/60.0)
		await ticks(1)
	assert(is_equal_approx(player.body.global_position.y-entry_origin.y,24.0))
	assert(not player.sprite.visible)
	assert(level.active_area == main_area)
	assert(main_area.get_node("Camera2D").global_position == source_camera_position)
	for tick in range(24):
		player.state_machine.process_physics(1.0/60.0)
		await ticks(1)
	await get_tree().process_frame
	assert(level.player == player and level.active_area == lower)
	assert(level.players.get_index() > level.get_node("Areas").get_index())
	assert(player.body.global_position == lower.get_node("Arrival").global_position)
	assert(player.body.velocity == Vector2.ZERO)
	assert(player.body.collision_layer != 0 and player.body.collision_mask != 0)
	assert(player.sprite.visible)
	assert(get_viewport().get_camera_2d() == lower.get_node("Camera2D"))
	assert(not main_area.runtime_loaded and not main_area.has_node("Camera2D"))
	assert(GameHandler.get_session_value(&"current_area_id") == &"lower")
	assert(GameHandler.get_session_value(&"coins") == 7)
	assert(player.state_machine.current_state == player.state_machine.initial_state)
	assert(not level.request_area_transfer(&"lower"))
	ControllerHandler.input_down = 0
	level.shutdown()
	assert(not is_instance_valid(pipe) and not level.request_area_transfer(&"main"))
	assert(not is_instance_valid(visuals) or visuals.is_queued_for_deletion())
	game.free()
	await ticks(6)
	print("PASS: painted solid pipe, alignment/ground/control gates, deferred one-way transfer, camera switch, state reset, session preservation, and shutdown.")
	get_tree().quit()
