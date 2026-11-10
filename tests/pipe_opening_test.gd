extends Node

const STAGE := preload("res://scenes/levels/worlds/world 1/1-2.tscn")

signal tick_finished


func _physics_process(_delta: float) -> void:
	tick_finished.emit()


func _ready() -> void:
	process_physics_priority = 200
	var preview := STAGE.instantiate() as BaseLevel
	var preview_opening := preview.opening_presentation
	var placement := preview_opening.intro_area.transport_points[0].duplicate() as TransportPlacement
	placement.target_id = &"preview_pipe"
	preview_opening.intro_area.transport_points[0] = placement
	preview_opening.entrance_id = placement.target_id
	add_child(preview)
	assert(preview.active_area.area_id == &"intro")
	var preview_doorway := preview.opening_presentation.resolve_spawn(preview.area_content)
	assert(preview.player.body.global_position.is_equal_approx(preview_doorway.global_position))
	await _wait_for_pipe(preview.player)
	for frame in range(120):
		if preview.active_area.area_id == &"main":
			break
		await tick_finished
	assert(preview.active_area.area_id == &"main")
	preview.free()
	await tick_finished

	var game := preload("res://scenes/main/game.tscn").instantiate()
	game.start_with_title = false
	game.start_stage_override = null
	add_child(game)
	for frame in range(240):
		if GameHandler.current_level != null and not GameHandler.transitions.busy:
			break
		await tick_finished
	var first_stage := GameHandler.current_level
	assert(first_stage != null and first_stage.stage_label == "1-1" and first_stage.has_started)
	var pole := first_stage.active_area.get_node("WorldObjects/flagpole_196_2") as FlagpoleEntity
	var first_player := first_stage.player
	first_player.body.global_position = Vector2(pole.climb_top.global_position.x - 7.0, 100.0)
	first_player.body.velocity = Vector2.ZERO
	var camera := get_viewport().get_camera_2d() as LevelCamera
	camera.snap_to_arrival(first_player.body)
	first_stage.active_area.update_camera_activity()
	GameHandler.time_remaining = 2
	for frame in range(10):
		if first_stage.ending_in_progress:
			break
		await tick_finished
	assert(first_stage.ending_in_progress)
	for frame in range(1200):
		if GameHandler.current_level != first_stage and not GameHandler.transitions.busy:
			break
		await tick_finished
	var level := GameHandler.current_level
	assert(
		level != null and level.stage_label == "1-2" and not GameHandler.transitions.busy,
		"Finishing the flagpole sequence should reveal 1-2."
	)
	assert(GameHandler.current_stage_index == 1)
	assert(level.active_area.area_id == &"intro")
	var player := level.player
	var doorway := level.opening_presentation.resolve_spawn(level.area_content)
	assert(doorway != null and player.body.global_position.is_equal_approx(doorway.global_position))
	assert(get_viewport().get_camera_2d() == level.active_area.get_node("Camera2D"))
	assert(not level.has_started and GameHandler.time_remaining == 400)
	var opening_cue := MusicHandler.PIPE_OPENING_CUE
	assert(MusicHandler._voice.stream == opening_cue and MusicHandler._voice.playing)
	assert(opening_cue.loop_mode == AudioStreamWAV.LOOP_DISABLED)
	assert(is_equal_approx(opening_cue.get_length(), 144.0 / 60.0))

	# Opposing input must not stop the automatic walk into the pipe.
	Input.action_press(ControllerHandler.left_action)
	await _wait_for_pipe(player)
	Input.action_release(ControllerHandler.left_action)
	assert(level.active_area.area_id == &"intro" and GameHandler.time_remaining == 400)

	for frame in range(240):
		if level.active_area.area_id == &"main":
			break
		assert(not player.can_read_controller_input())
		await tick_finished
	assert(level.active_area.area_id == &"main" and level.active_target_id == &"arrival")
	assert(level.player == player)
	assert(not player.scripted_motion_step.is_valid())
	var arrival := level.active_area.get_node("Arrival") as AreaEndpoint
	assert(not arrival.global_position.is_equal_approx(level.player_spawn.global_position))
	assert(level.active_endpoint == arrival)
	assert(player.body.global_position.is_equal_approx(arrival.global_position))
	assert(player.arrival_control_ticks_remaining == BasePlayer.ARRIVAL_CONTROL_TICKS)
	assert(not level.has_started)
	assert(MusicHandler._voice.stream == null)
	for frame in range(120):
		if level.has_started:
			break
		assert(not player.can_read_controller_input())
		await tick_finished
	assert(level.has_started and GameHandler.time_remaining == 400)
	var underground_music: AudioStreamWAV = MusicHandler._loops[MusicHandler.Track.UNDERGROUND]
	assert(MusicHandler._voice.stream == underground_music)
	assert(player.can_read_controller_input() and not player.body.is_on_floor())

	level.death_sound = null
	level.death_fallback_delay = 0.0
	assert(level.on_death(player, false))
	assert(level.death_restart_entry == BaseLevel.EntryMode.RESPAWN)
	for frame in range(360):
		if GameHandler.current_level != null and GameHandler.current_level != level:
			break
		await tick_finished
	var restarted := GameHandler.current_level
	assert(restarted != null and restarted != level)
	assert(restarted.active_area.area_id == &"main")
	assert(not restarted.player.scripted_motion_step.is_valid())
	assert(
		restarted.player.body.global_position.is_equal_approx(
			restarted.player_spawn.global_position
		)
	)
	assert(restarted.player.arrival_control_ticks_remaining == 0)
	for frame in range(240):
		if not GameHandler.transitions.busy:
			break
		await tick_finished
	assert(not GameHandler.transitions.busy)
	assert(restarted.has_started and restarted.player.can_read_controller_input())
	assert(MusicHandler._voice.stream == underground_music)
	game.free()
	await tick_finished
	print("PASS: 1-1 handoff, configurable automatic pipe opening, and underground respawn")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func _wait_for_pipe(player: BasePlayer) -> void:
	assert(player.scripted_motion_step.is_valid())
	for frame in range(300):
		assert(not player.can_read_controller_input())
		if player.state_machine.current_state == player.pipe_enter_state:
			break
		await tick_finished
	assert(player.state_machine.current_state == player.pipe_enter_state)
