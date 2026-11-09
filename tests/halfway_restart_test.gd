extends Node

signal tick_finished


func _physics_process(_delta: float) -> void:
	tick_finished.emit()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 200
	var game := preload("res://scenes/main/game.tscn").instantiate()
	game.start_with_title = false
	game.starting_lives = 6
	add_child(game)
	var level := await _wait_for_level_start()
	assert(_spawn_matches(level, 48.0, 0.0))

	var camera := get_viewport().get_camera_2d() as LevelCamera
	assert(camera.halfway_check_enabled and camera.halfway_camera_left == 1280.0)
	assert(level.halfway_spawn.position == Vector2(1344, 208))

	_set_camera_left(1279.0)
	level = await _restart(level, 48.0, 0.0)

	_set_camera_left(1280.0)
	level = await _restart(level, 1344.0, 1280.0)

	# Die again at the natural halfway framing, without moving the camera.
	level = await _restart(level, 1344.0, 1280.0)

	await _enter_lower_area(level, 896.0)
	level = await _restart(level, 48.0, 0.0, BaseLevel.DeathReason.TIMEOUT)

	await _enter_lower_area(level, 1408.0)
	level = await _restart(level, 1344.0, 1280.0)

	assert(is_instance_valid(level) and GameHandler.player_status.lives == 0)
	game.free()
	await tick_finished
	print(
		"PASS: halfway restart at 1279 and 1280, repeat death, and lower-area deaths on both sides."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


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
	var half_width := camera.get_viewport_rect().size.x / (2.0 * camera.zoom.x)
	assert(is_equal_approx(camera.global_position.x - half_width, camera_left))


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
	var position := level.player.body.global_position
	var camera := get_viewport().get_camera_2d() as LevelCamera
	var half_width := camera.get_viewport_rect().size.x / (2.0 * camera.zoom.x)
	return (
		level.active_area.area_id == &"main"
		and is_equal_approx(position.x, spawn_x)
		and absf(position.y - 208.0) < 0.2
		and is_equal_approx(camera.global_position.x - half_width, camera_left)
	)


func _set_camera_left(left: float) -> void:
	var camera := get_viewport().get_camera_2d() as LevelCamera
	var half_width := camera.get_viewport_rect().size.x / (2.0 * camera.zoom.x)
	camera.global_position.x = left + half_width
	camera.force_update_scroll()
