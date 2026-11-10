extends Node

const STAGE := preload("res://scenes/levels/worlds/world 1/1-1.tscn")
const GAME := preload("res://tests/fixtures/silent_game.tscn")

signal tick_finished


func _physics_process(_delta: float) -> void:
	tick_finished.emit()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 200
	assert(is_equal_approx(MusicHandler._warning.get_length(), 168.0 / 60.0))
	assert(MusicHandler._voice.pitch_scale == 1.0 and MusicHandler._voice.volume_db == 0.0)
	for track: int in MusicHandler._fast_loops:
		var regular: AudioStreamWAV = MusicHandler._loops[track]
		var fast: AudioStreamWAV = MusicHandler._fast_loops[track]
		var tempo := 2.0 if track == MusicHandler.STARMAN_TRACK else 1.5
		assert(fast.mix_rate == regular.mix_rate)
		assert(absf(fast.get_length() * tempo - regular.get_length()) < 0.01)

	var game := _start_game(101)
	var level := await _wait_for_level_start()
	assert(GameHandler.time_remaining == 101 and not level.level_timer.is_hurry)
	assert(MusicHandler._voice.stream == MusicHandler._loops[MusicHandler.Track.OVERWORLD])
	await _wait_for_time(100)
	assert(MusicHandler._voice.stream == MusicHandler._loops[MusicHandler.Track.OVERWORLD])
	await _wait_for_time(99)
	assert(level.level_timer.is_hurry and _warning_playing())
	assert(is_equal_approx(MusicHandler._warning_resume_position, 96.0 / 60.0))
	var mario := level.player as Mario
	var jump := mario.play_sound_effect(SoundHandler.get_sound(&"jump_small"))
	SoundHandler.play_reward(&"coin")
	await get_tree().process_frame
	await tick_finished
	assert(jump.playing and SoundHandler.is_reward_voice_occupied())
	assert(MusicHandler._warning.get_sync_stream_volume(0) == -INF)
	assert(MusicHandler._warning.get_sync_stream_volume(1) == -INF)
	assert(MusicHandler._warning.get_sync_stream_volume(2) == 0.0)
	jump.stop()
	SoundHandler.stop_reward(&"coin")
	await get_tree().process_frame
	await tick_finished
	assert(MusicHandler._warning.get_sync_stream_volume(0) == 0.0)
	assert(MusicHandler._warning.get_sync_stream_volume(1) == 0.0)
	assert(GameHandler.request_pause_toggle())
	var paused_time := GameHandler.time_remaining
	for frame in range(8):
		await tick_finished
	assert(_warning_playing() and MusicHandler._voice.stream_paused)
	assert(GameHandler.time_remaining == paused_time)
	assert(GameHandler.request_pause_toggle())

	mario.starman.begin()
	await tick_finished
	assert(mario.starman.uses_starman_music() and _warning_playing())
	mario.starman.intervals_remaining = 4
	mario.damage._interval_ticks = 1
	await tick_finished
	assert(mario.starman.intervals_remaining == 3 and _warning_playing())
	await _wait_for_warning_end()
	assert(MusicHandler._voice.stream == MusicHandler._fast_loops[MusicHandler.Track.OVERWORLD])
	assert(GameHandler.time_remaining < 99)
	await _take_secret_pipe(level, mario)
	assert(level.level_timer.is_hurry)
	assert(MusicHandler._voice.stream == MusicHandler._fast_loops[MusicHandler.Track.UNDERGROUND])
	game.free()
	await tick_finished

	game = _start_game(100)
	level = await _wait_for_level_start()
	mario = level.player as Mario
	assert(not _warning_playing())
	mario.starman.begin()
	await tick_finished
	assert(MusicHandler._voice.stream == MusicHandler._loops[MusicHandler.STARMAN_TRACK])
	await _wait_for_time(99)
	assert(_warning_playing())
	await _wait_for_warning_end()
	assert(MusicHandler._voice.stream == MusicHandler._fast_loops[MusicHandler.STARMAN_TRACK])
	await _grab_flagpole(level)
	assert(MusicHandler._voice.stream == null)
	game.free()
	await tick_finished

	game = _start_game(75)
	level = await _wait_for_level_start()
	assert(GameHandler.time_remaining == 75 and _warning_playing())
	await _wait_for_warning_end()
	assert(MusicHandler._voice.stream == MusicHandler._fast_loops[MusicHandler.Track.OVERWORLD])
	game.free()
	await tick_finished

	game = _start_game(75)
	level = await _wait_for_level_start()
	assert(_warning_playing())
	await _grab_flagpole(level)
	assert(MusicHandler._voice.stream == null)
	# A late completion notification from a stopped warning cannot restart music.
	MusicHandler._voice.finished.emit()
	assert(MusicHandler._voice.stream == null)
	game.free()
	await tick_finished

	game = _start_game(75, false)
	level = await _wait_for_level_start()
	assert(not level.level_timer.is_hurry and not _warning_playing())
	game.free()
	await tick_finished
	game = _start_game(0)
	level = await _wait_for_level_start()
	assert(not level.level_timer.is_hurry and not _warning_playing())
	game.free()
	await tick_finished
	print("PASS: hurry threshold, low start, pulse priority, Starman, pipe, pause, and ending.")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func _start_game(time: int, timer_enabled: bool = true) -> Node:
	var fixture := STAGE.instantiate() as BaseLevel
	fixture.starting_time = time
	fixture.timer_enabled = timer_enabled
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area, true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	var game := GAME.instantiate()
	game.transitions_enabled = true
	game.stages.assign([packed])
	add_child(game)
	return game


func _wait_for_level_start() -> BaseLevel:
	for frame in range(240):
		var level := GameHandler.current_level
		if is_instance_valid(level) and level.has_started:
			return level
		assert(MusicHandler._voice.stream == null)
		await tick_finished
	assert(false, "Expected gameplay to reveal.")
	return null


func _wait_for_time(time: int) -> void:
	for frame in range(30):
		if GameHandler.time_remaining == time:
			return
		await tick_finished
	assert(false, "Expected time %s, got %s." % [time, GameHandler.time_remaining])


func _warning_playing() -> bool:
	return MusicHandler._voice.stream == MusicHandler._warning


func _wait_for_warning_end() -> void:
	for frame in range(240):
		if not _warning_playing():
			return
		await tick_finished
	assert(false, "Expected the one-shot warning to end.")


func _take_secret_pipe(level: BaseLevel, mario: Mario) -> void:
	var pipe := level.active_area.find_transport_entity(&"secret_entrance") as PipeEntrance
	assert(pipe != null)
	mario.body.global_position = pipe.entry_position()
	mario.body.velocity = Vector2.ZERO
	(get_viewport().get_camera_2d() as LevelCamera).snap_to_arrival(mario.body)
	for frame in range(5):
		await tick_finished
	assert(level.transport(mario, pipe.get_destination(), pipe))
	for frame in range(160):
		if level.active_area.area_id == &"lower" and not level.transition_in_progress:
			return
		await tick_finished
	assert(false, "Expected the secret room to reveal.")


func _grab_flagpole(level: BaseLevel) -> void:
	var player := level.player
	var pole := level.world_objects.get_node("flagpole_196_2") as FlagpoleEntity
	player.body.global_position = Vector2(pole.climb_top.global_position.x - 7, 100)
	player.body.velocity = Vector2.ZERO
	(get_viewport().get_camera_2d() as LevelCamera).snap_to_arrival(player.body)
	for frame in range(6):
		if level.ending_in_progress:
			return
		await tick_finished
	assert(false, "Expected an accepted flagpole grab.")
