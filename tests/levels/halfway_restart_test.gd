extends Node

signal tick_finished


func _physics_process(_delta: float) -> void:
	tick_finished.emit()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 200
	var game := preload("res://scenes/main/game.tscn").instantiate()
	game.start_stage_override = null
	game.start_with_title = false
	game.starting_lives = 6
	add_child(game)
	var level := await _wait_for_level_start()
	assert(_spawn_matches(level, 48.0, 0.0))

	var camera := get_viewport().get_camera_2d() as LevelCamera
	assert(camera.halfway_check_enabled and camera.halfway_camera_left == 1280.0)
	assert(level.halfway_spawn.position == Vector2(1328, 208))

	_set_camera_left(1279.0)
	level = await _restart(level, 48.0, 0.0)

	_set_camera_left(1280.0)
	level = await _restart(level, 1328.0, 1280.0)

	# Die again at the natural halfway framing, without moving the camera.
	level = await _restart(level, 1328.0, 1280.0)

	camera = get_viewport().get_camera_2d() as LevelCamera
	assert(camera.scroll_left_limit == 1280.0 and camera.world_left == 0.0)
	level.player.body.global_position.x += 128.0
	await tick_finished
	assert(_camera_left(camera) > 1280.0)
	await _enter_lower_area(level, 896.0)
	await _return_from_secret(level)

	await _enter_lower_area(level, 896.0)
	level = await _restart(level, 48.0, 0.0, BaseLevel.DeathReason.TIMEOUT)

	await _enter_lower_area(level, 1408.0)
	level = await _restart(level, 1328.0, 1280.0)

	assert(is_instance_valid(level) and GameHandler.player_status.lives == 0)
	await _check_1_2(game)
	game.free()
	await tick_finished
	print(
		"PASS: 1-1 and 1-2 halfway thresholds, left limits, repeat deaths, and side-area framing."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func _check_1_2(game: Node) -> void:
	# Exercise the same covered restart path with a shorter card for the added cases.
	var definition := GameHandler.transitions.get_definition(&"level") as TransitionDefinition
	var card_frames := definition.stages[0].minimum_frames
	definition.stages[0].minimum_frames = 8
	GameHandler.set_lives(4)
	game.enemy_limit = 8
	assert(GameHandler.load_level(game.stages[1], true, 1, BaseLevel.EntryMode.RESPAWN))
	var level := await _wait_for_level_start()
	assert(level.stage_label == "1-2" and _spawn_matches(level, 48.0, 0.0))
	var area_origin := level.active_area.global_position.x
	var camera := get_viewport().get_camera_2d() as LevelCamera
	assert(camera.halfway_check_enabled and camera.halfway_camera_left == 1536.0)
	assert(level.halfway_spawn.position == Vector2(1584, 208))

	_set_camera_left(area_origin + 1329.0)
	level.active_area.update_camera_activity()
	var triplet := _find_1_2_triplet(level)
	assert(triplet.get_child_count() == 4, "The normal approach should spawn all three Goombas.")

	_set_camera_left(area_origin + 1535.0)
	level = await _restart(level, 48.0, 0.0)
	assert(level.entry_mode == BaseLevel.EntryMode.RESPAWN)

	_set_camera_left(area_origin + 1536.0)
	level = await _restart(level, 1584.0, 1536.0)
	assert(level.entry_mode == BaseLevel.EntryMode.HALFWAY_RESPAWN)
	assert(_find_1_2_triplet(level).get_child_count() == 1)
	var objects := level.world_objects
	assert(objects.get_node("goomba_spawner_113_12").get_child_count() == 2)
	for pipe_name in ["pipe_entrance_103_10", "pipe_entrance_109_9"]:
		assert(objects.has_node(pipe_name + "/OccupantSpawner/GreenPiranhaPlant"))
	camera = get_viewport().get_camera_2d() as LevelCamera
	assert(camera.scroll_left_limit == area_origin + 1536.0)
	level = await _restart(level, 1584.0, 1536.0)
	triplet = _find_1_2_triplet(level)
	_set_camera_left(area_origin + 16.0 + 1536.0)
	level.active_area.update_camera_activity()
	assert(triplet.get_child_count() == 1, "The skipped triplet must stay absent as the camera advances.")

	# The authored bonus room lies beyond the threshold in world coordinates.
	assert(level.request_area_transfer(&"bonus"))
	for frame in range(120):
		if level.active_area.area_id == &"bonus" and not level.transition_in_progress:
			break
		await tick_finished
	assert(level.active_area.area_id == &"bonus" and not level.area_transport.pending)
	level = await _restart(level, 1584.0, 1536.0)
	assert(level.entry_mode == BaseLevel.EntryMode.HALFWAY_RESPAWN)
	assert(GameHandler.player_status.lives == 0)
	definition.stages[0].minimum_frames = card_frames


func _find_1_2_triplet(level: BaseLevel) -> EntitySpawner:
	return level.world_objects.get_node("goomba_triplet_spawner_99_12") as EntitySpawner


func _enter_lower_area(level: BaseLevel, camera_left: float) -> void:
	var lower_area := level.get_node("Areas/LowerArea") as BaseLevelArea
	lower_area.global_position.x = camera_left
	assert(level.request_area_transfer(&"lower"))
	for frame in range(120):
		if (
			level.active_area.area_id == &"lower"
			and not level.transition_in_progress
			and level.player.body.is_on_floor()
		):
			break
		await tick_finished
	assert(level.active_area.area_id == &"lower" and not level.area_transport.pending)
	assert(not level.transition_in_progress and level.player.body.is_on_floor())
	var camera := get_viewport().get_camera_2d() as LevelCamera
	assert(camera == lower_area.get_node("Camera2D"))
	assert(is_equal_approx(_camera_left(camera), camera_left))
	assert(is_equal_approx(camera.scroll_left_limit, camera_left))


func _return_from_secret(level: BaseLevel) -> void:
	var pipe := level.active_area.find_transport_entity(&"secret_return") as PipeEntrance
	assert(pipe != null)
	assert(level.transport(level.player, pipe.get_destination()))
	for frame in range(240):
		await tick_finished
		if level.active_area.area_id == &"main" and not level.area_transport.has_active_state():
			break
	assert(level.active_area.area_id == &"main" and level.active_target_id == &"secret_exit")
	assert(not level.area_transport.has_active_state())
	var camera := get_viewport().get_camera_2d() as LevelCamera
	assert(camera.scroll_left_limit == 1280.0)
	assert(is_equal_approx(level.player.body.global_position.x - _camera_left(camera), 64.0))
	# An arrival framed left of the checkpoint must still clamp to the painted line.
	camera.snap_to_arrival(level.player.body, level.player.body.global_position.x)
	assert(is_equal_approx(_camera_left(camera), 1280.0))


func _restart(
	old_level: BaseLevel,
	spawn_x: float,
	camera_left: float,
	reason: BaseLevel.DeathReason = BaseLevel.DeathReason.NORMAL
) -> BaseLevel:
	old_level.death_sound = null
	old_level.death_fallback_delay = 0.0
	assert(old_level.on_death(old_level.player, false, reason))
	for frame in range(420):
		var level := GameHandler.current_level
		if is_instance_valid(level) and level != old_level:
			assert(level.transition_in_progress)
			assert(
				_spawn_matches(level, spawn_x, camera_left),
				(
					"Expected restart X %s and camera left %s, got player at %s."
					% [spawn_x, camera_left, level.player.body.global_position]
				)
			)
			level = await _wait_for_level_start()
			assert(level.player.arrival_control_ticks_remaining == 0)
			assert(level.player.can_read_controller_input())
			return level
		await tick_finished
	assert(false, "Death never loaded a replacement level.")
	return null


func _wait_for_level_start() -> BaseLevel:
	for frame in range(240):
		var level := GameHandler.current_level
		if is_instance_valid(level) and level.has_started:
			return level
		await tick_finished
	assert(false, "The level never started.")
	return null


func _spawn_matches(level: BaseLevel, spawn_x: float, camera_left: float) -> bool:
	var area := level.active_area
	var position := area.to_local(level.player.body.global_position)
	var camera := get_viewport().get_camera_2d() as LevelCamera
	return (
		area.area_id == &"main"
		and is_equal_approx(position.x, spawn_x)
		and absf(position.y - 208.0) < 0.2
		and is_equal_approx(_camera_left(camera) - area.global_position.x, camera_left)
	)


func _set_camera_left(left: float) -> void:
	var camera := get_viewport().get_camera_2d() as LevelCamera
	var half_width := camera.get_viewport_rect().size.x / (2.0 * camera.zoom.x)
	camera.global_position.x = left + half_width
	camera.force_update_scroll()


func _camera_left(camera: LevelCamera) -> float:
	return camera.global_position.x - camera.get_viewport_rect().size.x / (2.0 * camera.zoom.x)
