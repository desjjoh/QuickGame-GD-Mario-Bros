extends Node
## Opt-in diagnostic scene. Nothing attaches this recorder during normal gameplay.
var _camera: Camera2D
var _previous_x: float = 0.0
var _current_x: float = 0.0
var _step: int = 0
var _automatic: bool = false
var _seconds: float = 60.0
var _game: Node
var _samples: Array[PackedFloat64Array] = []
var _saved: bool = false
var _player: BasePlayer
var _previous_body: Vector2
var _body_step: Vector2


func _physics_process(_delta: float) -> void:
	var active := get_viewport().get_camera_2d()
	if active != _camera:
		_camera = active
		if is_instance_valid(_camera):
			_current_x = _camera.global_position.x
	_previous_x = _current_x
	if is_instance_valid(_camera):
		_current_x = _camera.global_position.x
	var player := GameHandler.current_player
	if is_instance_valid(player):
		if player != _player:
			_player = player
			_previous_body = player.body.global_position
		_body_step = player.body.global_position - _previous_body
		_previous_body = player.body.global_position
	_step += 1
	if _automatic and is_instance_valid(GameHandler.current_player):
		if _step % 100 == 0 and GameHandler.current_player.body.is_on_floor():
			Input.action_press(ControllerHandler.primary_action)
		elif _step % 100 == 12:
			Input.action_release(ControllerHandler.primary_action)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Frame pacing capture requires a rendered window.")
		get_tree().quit(1)
		return
	process_physics_priority = 1000
	for argument in OS.get_cmdline_user_args():
		if argument == "--pacing-auto":
			_automatic = true
		if argument.begins_with("--pacing-seconds="):
			_seconds = clampf(argument.get_slice("=", 1).to_float(), 1.0, 600.0)
	if _automatic:
		var factory: Node = load("res://tests/camera_follow_test.gd").new()
		_game = factory.make_game()
		factory.free()
	else:
		_game = load("res://scenes/main/game.tscn").instantiate()
	add_child(_game)
	if _automatic:
		var camera := get_viewport().get_camera_2d() as LevelCamera
		camera.world_right = 8000.0
		var floor := (
			GameHandler.current_level.get_node("Areas/MainArea/Layouts/GroundLayout")
			as TileMapLayer
		)
		for x in range(48, 512):
			floor.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
		Input.action_press(ControllerHandler.right_action)
		Input.action_press(ControllerHandler.secondary_action)
	# Warm up without readback, disk writes or per-frame console output.
	for frame in range(60):
		await RenderingServer.frame_post_draw
	var start_us := Time.get_ticks_usec()
	var last_us := start_us
	while Time.get_ticks_usec() - start_us < int(_seconds * 1000000.0):
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		var fraction := Engine.get_physics_interpolation_fraction()
		var expected := NAN
		if is_instance_valid(_camera):
			expected = (
				get_viewport().get_visible_rect().size.x / 2.0
				- lerpf(_previous_x, _current_x, fraction)
			)
		var body_position := Vector2.ZERO
		var velocity := Vector2.ZERO
		var native_step := Vector2.ZERO
		var floor_contact := false
		var state_code := 0
		if is_instance_valid(_player):
			body_position = _player.body.global_position
			velocity = _player.body.velocity
			native_step = _player.body.get_position_delta()
			floor_contact = _player.body.is_on_floor()
			var state := _player.state_machine.current_state
			if state != null:
				state_code = {&"Idle": 1, &"Move": 2, &"Slide": 3, &"Jump": 4}.get(state.name, 5)
		_samples.append(
			PackedFloat64Array(
				[
					float(now - start_us) / 1000.0,
					float(now - last_us) / 1000.0,
					float(Engine.get_physics_frames()),
					fraction,
					_previous_x,
					_current_x,
					get_viewport().canvas_transform.origin.x,
					expected,
					Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
					Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
					Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					float(GameHandler.transitions.busy),
					body_position.x,
					body_position.y,
					velocity.x,
					velocity.y,
					_body_step.x,
					_body_step.y,
					native_step.x,
					native_step.y,
					float(floor_contact),
					float(state_code)
				]
			)
		)
		last_us = now
	_save()
	set_physics_process(false)
	if _automatic:
		Input.action_release(ControllerHandler.right_action)
		Input.action_release(ControllerHandler.secondary_action)
		Input.action_release(ControllerHandler.primary_action)
	get_tree().quit()


func _save() -> void:
	if _saved or _samples.is_empty():
		return
	_saved = true
	DirAccess.make_dir_recursive_absolute("user://diagnostics")
	var path := "user://diagnostics/frame-pacing-%s.csv" % Time.get_ticks_usec()
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		push_error("Could not save frame pacing capture: %s" % FileAccess.get_open_error())
		return
	output.store_csv_line(
		PackedStringArray(
			[
				"elapsed_ms",
				"frame_ms",
				"physics_frame",
				"fraction",
				"previous_camera_x",
				"camera_x",
				"render_origin_x",
				"expected_origin_x",
				"process_ms",
				"physics_ms",
				"draw_calls",
				"transition_busy",
				"player_x",
				"player_y",
				"velocity_x",
				"velocity_y",
				"body_step_x",
				"body_step_y",
				"native_step_x",
				"native_step_y",
				"on_floor",
				"state_code"
			]
		)
	)
	var intervals: Array[float] = []
	for sample in _samples:
		var line := PackedStringArray()
		for value in sample:
			line.append(str(value))
		output.store_csv_line(line)
		intervals.append(sample[1])
	output.close()
	intervals.sort()
	print(
		(
			"PACING: %s frames; median %.3f ms, p99 %.3f ms, max %.3f ms. CSV: %s"
			% [
				_samples.size(),
				intervals[int(intervals.size() / 2)],
				intervals[int(intervals.size() * 0.99)],
				intervals[-1],
				ProjectSettings.globalize_path(path)
			]
		)
	)


func _exit_tree() -> void:
	# Preserve a partial capture when the diagnostic window is closed early.
	_save()
