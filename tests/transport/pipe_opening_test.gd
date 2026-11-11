extends Node

const STAGE := preload("res://scenes/levels/worlds/world 1/1-2.tscn")
const DRAW_ORDER := preload("res://scenes/components/presentation/draw_order.gd")

signal tick_finished


func _physics_process(_delta: float) -> void:
	tick_finished.emit()


func _ready() -> void:
	process_physics_priority = 200
	var preview := STAGE.instantiate() as BaseLevel
	var preview_opening := preview.opening_presentation
	var placement := (
		preview_opening.intro_area.transport_points[0].duplicate() as TransportPlacement
	)
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
	var first_player := first_stage.player as Mario
	assert(first_player.grow())
	for frame in range(180):
		if not first_player.form_presentation.active:
			break
		await tick_finished
	assert(first_player.form_controller.current_form == first_player.super_form)
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
	var player := level.player as Mario
	assert(player.form_controller.current_form == player.super_form)
	assert(player.sprite.texture == player.super_form.idle)
	assert(player.enemy_hurtbox.get_node("CollisionShape2D").shape.size == Vector2(12, 24))
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
	assert(player.form_controller.current_form == player.super_form)
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
	var respawned := restarted.player as Mario
	var start_form := restarted.player_start_configuration as MarioForm
	assert(
		(
			respawned.form_controller.current_form
			== (start_form if start_form else respawned.small_form)
		)
	)
	var expected_status := PlayerStatus.PowerupForm.SMALL
	if start_form == respawned.fire_form:
		expected_status = PlayerStatus.PowerupForm.FIRE
	elif start_form == respawned.super_form:
		expected_status = PlayerStatus.PowerupForm.SUPER
	assert(GameHandler.player_status.powerup_form == expected_status)
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

	await _take_pipe(restarted, &"bonus_entrance", &"bonus", &"arrival")
	assert(restarted.active_endpoint == restarted.active_area.get_node("Arrival"))
	await _take_pipe(restarted, &"bonus_return", &"main", &"bonus_return_exit")
	await _take_pipe(restarted, &"surface_entrance", &"surface", &"surface_exit")
	await _finish_surface(restarted)
	assert(GameHandler.show_title(game.stages[0]))
	await _check_warps()
	game.free()
	await tick_finished
	print("PASS: 1-2 opening, respawn, secret round trip, handoff to 1-3, and three stage warps")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func _wait_for_pipe(player: BasePlayer) -> void:
	assert(player.scripted_motion_step.is_valid())
	for frame in range(300):
		assert(not player.can_read_controller_input())
		if player.state_machine.current_state == player.pipe_enter_state:
			break
		await tick_finished
	assert(player.state_machine.current_state == player.pipe_enter_state)


func _take_pipe(
	level: BaseLevel, source_id: StringName, area_id: StringName, target_id: StringName
) -> void:
	await _enter_pipe(level, source_id)
	var player := level.player
	for frame in range(360):
		if (
			level.active_area.area_id == area_id
			and level.can_transport()
			and player.can_read_controller_input()
		):
			break
		await tick_finished
	assert(level.active_area.area_id == area_id and level.active_target_id == target_id)
	assert(level.player == player and player.state_machine.current_state != player.pipe_enter_state)
	assert(player.can_read_controller_input())
	assert(get_viewport().get_camera_2d() == level.active_area.get_node("Camera2D"))
	var exit := level.active_area.find_transport_entity(target_id) as PipeEntrance
	if exit != null:
		assert(not exit.entrance_enabled)
		assert(absf(player.body.global_position.x - exit.exit_position().x) < 1.0)


func _enter_pipe(level: BaseLevel, source_id: StringName) -> void:
	var pipe := level.active_area.find_transport_entity(source_id) as PipeEntrance
	assert(pipe != null)
	var player := level.player
	player.body.global_position = (
		pipe.entry_position() - Vector2(12.0 if pipe.sideways else 0.0, 0.0)
	)
	player.body.velocity = Vector2.ZERO
	var camera := get_viewport().get_camera_2d() as LevelCamera
	camera.snap_to_arrival(player.body)
	for frame in range(5):
		await tick_finished
	var action := ControllerHandler.right_action if pipe.sideways else ControllerHandler.down_action
	Input.action_press(action)
	for frame in range(60):
		if player.state_machine.current_state == player.pipe_enter_state:
			break
		await tick_finished
	Input.action_release(action)
	assert(
		player.state_machine.current_state == player.pipe_enter_state,
		"Could not enter %s." % source_id
	)


func _finish_surface(level: BaseLevel) -> void:
	var ending := level.ending_presentation as FlagpoleEndingPresentation
	assert(ending != null and ending.area_id == level.active_area.area_id)
	var pole := (
		level.area_content.find_layout_entity(level.active_area, &"flagpole", ending.flagpole_cell)
		as FlagpoleEntity
	)
	assert(pole != null)
	var player := level.player
	player.body.global_position = pole.climb_top.global_position + Vector2(-7.0, 60.0)
	player.body.velocity = Vector2.ZERO
	var camera := get_viewport().get_camera_2d() as LevelCamera
	camera.snap_to_arrival(player.body)
	level.active_area.update_camera_activity()
	GameHandler.time_remaining = 10
	for frame in range(6):
		if level.ending_in_progress:
			break
		await tick_finished
	assert(level.ending_in_progress)
	for frame in range(1200):
		if GameHandler.current_level != level and not GameHandler.transitions.busy:
			break
		await tick_finished
	var next := GameHandler.current_level
	assert(next != null and next != level and next.stage_label == "1-3")
	assert(GameHandler.current_stage_index == 2 and not GameHandler.transitions.busy)
	assert(GameHandler.flow == GameHandler.GameFlow.PLAYING and next.has_started)
	assert(next.get_node("Areas").get_child_count() == 1)
	assert(next.active_area.area_id == &"main" and next.active_area.theme.display_name == "Overworld")
	assert(next.player.body.global_position.is_equal_approx(next.player_spawn.global_position))


func _check_warps() -> void:
	assert(GameHandler.title_flow.start_new_game(null, GameHandler.PlayerCharacter.LUIGI))
	for frame in range(240):
		if GameHandler.flow == GameHandler.GameFlow.PLAYING and not GameHandler.transitions.busy:
			break
		await tick_finished
	assert(GameHandler.flow == GameHandler.GameFlow.PLAYING and not GameHandler.transitions.busy)
	for pipe_id in [&"warp_4", &"warp_3", &"warp_2"]:
		assert(GameHandler.load_level(STAGE, true, 1, BaseLevel.EntryMode.RESPAWN))
		var source := GameHandler.current_level
		var traveler := source.player as Mario
		traveler.form_controller.configure(traveler, traveler.fire_form)
		GameHandler.set_player_form(PlayerStatus.PowerupForm.FIRE)
		GameHandler.set_score(1230)
		GameHandler.set_coins(7)
		var zone := source.world_objects.get_node("WarpZone")
		var banner := zone.get_node("Presentation") as Node2D
		var camera := source.active_area.get_node("Camera2D") as LevelCamera
		var marker := zone.get_node("RevealMarker") as Marker2D
		var half_width := source.get_viewport_rect().size.x / (2.0 * camera.zoom.x)
		var pipe := source.active_area.find_transport_entity(pipe_id) as WarpZonePipe
		assert(pipe != null and not pipe.entrance_enabled and not banner.visible)
		traveler.body.global_position = pipe.entry_position()
		camera.follow_enabled = false
		var reveal_center := marker.global_position.x + half_width
		if pipe_id == &"warp_4":
			camera.global_position.x = reveal_center - 1.0
			for frame in range(2):
				await tick_finished
			assert(not banner.visible and not pipe.entrance_enabled)
		camera.global_position.x = reveal_center
		for frame in range(2):
			await tick_finished
		assert(banner.visible and pipe.entrance_enabled)
		assert(not banner.z_as_relative and banner.z_index == DRAW_ORDER.BEHIND_WORLD)
		for warp: WarpZonePipe in zone.get_node("Pipes").get_children():
			var number := warp.get_node("WorldNumber") as Label
			assert(number.visible and number.text == warp.display_text)
			assert(not number.z_as_relative and number.z_index == DRAW_ORDER.BEHIND_WORLD)
			assert(not warp.has_node("OccupantSpawner"))
		await _enter_pipe(source, pipe_id)
		assert(GameHandler.current_level == source and not source.completion_in_progress)
		for frame in range(300):
			if GameHandler.current_level != source and not GameHandler.transitions.busy:
				break
			await tick_finished
		assert(GameHandler.current_level != source and not GameHandler.transitions.busy)
		assert(
			GameHandler.current_level.stage_label == "1-1" and GameHandler.current_stage_index == 0
		)
		assert(GameHandler.current_level.entry_mode == BaseLevel.EntryMode.STAGE_START)
		var arrived := GameHandler.current_player as Mario
		assert(arrived.scene_file_path == "res://scenes/player/luigi/luigi.tscn")
		assert(arrived.form_controller.current_form == arrived.fire_form)
		assert(GameHandler.player_status.score == 1230 and GameHandler.player_status.coins == 7)
