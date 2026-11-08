extends Node

signal tick_finished
var changes: Array[int] = []


func _physics_process(_delta: float) -> void:
	tick_finished.emit()


func ticks(count: int = 1) -> void:
	for frame in range(count):
		await tick_finished


func wait_phase(
	ending: FlagpoleEndingPresentation, phase: FlagpoleEndingPresentation.Phase
) -> void:
	for frame in range(900):
		if ending.phase == phase:
			return
		await ticks()
	assert(false, "Ending did not reach phase %s (current %s)" % [phase, ending.phase])


func make_game(manual: bool) -> Node:
	var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	if "--super" in OS.get_cmdline_user_args():
		fixture.player_start_configuration = preload("res://assets/player/forms/super.tres")
	var ending := fixture.ending_presentation as FlagpoleEndingPresentation
	fixture.set_editable_instance(ending, true)
	if manual:
		ending.music = null
		ending.get_node("Score").set_script(load("res://tests/fixtures/manual_ending_step.gd"))
		ending.get_node("Fireworks").set_script(load("res://tests/fixtures/manual_ending_step.gd"))
	var packed := PackedScene.new()
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area, true)
	assert(packed.pack(fixture) == OK)
	fixture.free()
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.stages.assign([packed])
	return game


func grab(level: BaseLevel, height: float = 100.0) -> void:
	var pole := level.active_area.get_node("WorldObjects/flagpole_196_2") as FlagpoleEntity
	var player := level.player
	player.body.global_position = Vector2(pole.climb_top.global_position.x - 7, height)
	player.body.velocity = Vector2.ZERO
	var camera := get_viewport().get_camera_2d() as LevelCamera
	camera.snap_to_arrival(player.body)
	level.active_area.update_camera_activity()
	await ticks(2)
	assert(level.ending_in_progress and GameHandler.flow == GameHandler.GameFlow.COMPLETING)
	assert(not level.on_complete() and not level.on_death(player, false))
	assert(not level.request_area_transfer(&"lower"))
	assert(camera.is_scroll_locked())
	var ending := level.ending_presentation as FlagpoleEndingPresentation
	assert(ending._audio != null and not ending._music_started)
	assert((ending._audio.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 200
	for boundary in [[16, 100, 400], [56, 400, 800], [80, 800, 2000], [126, 2000, 5000]]:
		assert(FlagpoleEndingPresentation.points_for_grab_height(boundary[0]) == boundary[1])
		assert(FlagpoleEndingPresentation.points_for_grab_height(boundary[0] + 0.01) == boundary[2])
	var game := make_game(true)
	add_child(game)
	var level := GameHandler.current_level
	var ending := level.ending_presentation as FlagpoleEndingPresentation
	ending.music = null
	ending.phase_changed.connect(capture_phase)
	var player := level.player
	var camera := get_viewport().get_camera_2d() as LevelCamera
	GameHandler.set_top_score(123456)
	var score_before := GameHandler.player_status.score
	var time_before := GameHandler.time_remaining
	ending.phase_changed.connect(
		func(phase: FlagpoleEndingPresentation.Phase) -> void:
			if phase == FlagpoleEndingPresentation.Phase.DESCEND:
				var base := ending._pole.climb_bottom.global_position
				assert(ending._score_popup.global_position == base + Vector2(12, -14))
				assert(not ending._score_popup.is_physics_interpolated())
	)
	await grab(level)
	await preload("res://tests/fixtures/pause_check.gd").check(level)
	assert(ending.grab_height == 92.0 and ending.remaining_time_at_contact == time_before)
	assert(ending.grab_points == 2000 and GameHandler.player_status.score == score_before)
	assert(ending._score_popup.visible and ending._score_popup.region_rect == Rect2(16, 8, 16, 8))
	var popup_start := ending._score_popup.global_position.y
	var locked_x := camera.global_position.x
	Input.action_press("ui_left")
	Input.action_press("ui_up")
	Input.action_press("secondary")
	var pole := level.active_area.get_node("WorldObjects/flagpole_196_2") as FlagpoleEntity
	var flag_start: float = pole.get_node("Presentation/Flag").global_position.y
	for frame in range(15):
		var previous_y := ending._score_popup.global_position.y
		await ticks()
		var rise := previous_y - ending._score_popup.global_position.y
		assert(rise >= 1.0 and rise <= 2.0)
		assert(camera.global_position.x == locked_x)
		assert(player.state_machine.current_state == player.climb_state)
		assert(player.scripted_motion_step.is_valid())
	assert(player.body.global_position.y > 100 and player.body.velocity.x == 0)
	assert(pole.get_node("Presentation/Flag").global_position.y > flag_start)
	assert(ending._score_popup.global_position.y < popup_start)
	assert(GameHandler.player_status.score == score_before)
	assert(GameHandler.time_remaining == time_before)
	Input.action_release("ui_left")
	Input.action_release("ui_up")
	Input.action_release("secondary")
	var held_at_cutoff := false
	for frame in range(90):
		if ending.phase != FlagpoleEndingPresentation.Phase.DESCEND:
			break
		if player.body.global_position.y == ending._descent_stop_y:
			held_at_cutoff = true
			assert(player.body.velocity == Vector2.ZERO)
			assert(not player.animation_player.is_playing())
			assert(player.animation_player.current_animation_position == 0.0)
		await ticks()
	assert(held_at_cutoff, "The test must observe Mario waiting at the bottom.")
	await wait_phase(ending, FlagpoleEndingPresentation.Phase.DISMOUNT)
	assert(absf(player.body.global_position.y - (pole.climb_bottom.global_position.y - 2)) < 0.1)
	assert(is_equal_approx(player.body.global_position.x, pole.climb_bottom.global_position.x + 7))
	assert(player.sprite.flip_h)
	var flag_end: float = pole.get_node("Presentation/Flag").global_position.y
	assert(flag_end == pole.climb_bottom.global_position.y - 13.0)
	assert(GameHandler.player_status.score == score_before + 2000)
	await ticks(23)
	assert(ending.phase == FlagpoleEndingPresentation.Phase.DISMOUNT)
	assert(GameHandler.player_status.score == score_before + 2000)
	await ticks()
	assert(
		ending.phase == FlagpoleEndingPresentation.Phase.WALK,
		"Phase %s endpoint %s" % [ending.phase, ending._castle.doorway.global_position]
	)
	assert(player.body.global_position.x > pole.climb_bottom.global_position.x + 10)
	var retired: WeakRef = weakref(player)
	assert(ending._walk_endpoint == ending._castle.doorway.global_position)
	var walk_steps := 0
	await preload("res://tests/fixtures/pause_check.gd").check(level)
	for frame in range(400):
		walk_steps += 1
		var previous_camera := camera.global_position.x
		await ticks()
		assert(
			camera.global_position.x - previous_camera <= 1.6,
			"Unlock must not catch up accumulated side/dismount motion."
		)
		if ending.phase == FlagpoleEndingPresentation.Phase.SCORE:
			break
	assert(ending.phase == FlagpoleEndingPresentation.Phase.SCORE)
	assert(level.player == null and GameHandler.current_player == null)
	assert(walk_steps >= 30, "The endpoint must require a real walk to the castle.")
	await ticks(2)
	assert(
		retired.get_ref() == null and level.player == null and GameHandler.current_player == null
	)
	assert(not camera.is_scroll_locked())
	assert(GameHandler.flow == GameHandler.GameFlow.COMPLETING)
	assert(not level.finish_ending(ending))
	await ticks(20)
	assert(ending.phase == FlagpoleEndingPresentation.Phase.SCORE)
	var score_ticket := ending.score_step.current_ticket
	ending.score_step.complete(score_ticket - 1)
	assert(ending.phase == FlagpoleEndingPresentation.Phase.SCORE)
	ending.score_step.complete(score_ticket)
	assert(ending.phase == FlagpoleEndingPresentation.Phase.RAISE_FLAG)
	var castle := ending._castle
	assert(castle.doorway.global_position == Vector2(3256, 208))
	assert(castle._flag.visible and castle._flag.position.y == 16.0)
	# The presentation must keep the flag moving outside the activity buffer.
	level.active_area.set_physics_process(false)
	castle.set_activity_suspended(true)
	for frame in range(31):
		await ticks()
		assert(ending.phase == FlagpoleEndingPresentation.Phase.RAISE_FLAG)
		assert(castle.activity_suspended and castle._flag.position.y == 15.0 - frame)
	await ticks()
	assert(ending.phase == FlagpoleEndingPresentation.Phase.FIREWORKS)
	level.active_area.set_physics_process(true)
	await ticks(20)
	assert(GameHandler.current_level == level)
	ending.fireworks_step.complete(ending.fireworks_step.current_ticket)
	assert(ending.phase == FlagpoleEndingPresentation.Phase.WAIT)
	await ticks(125)
	assert(GameHandler.current_level == level)
	await ticks(2)
	assert(GameHandler.flow == GameHandler.GameFlow.TITLE)
	assert(GameHandler.top_score == 123456)
	game.free()
	await ticks(3)
	# Real music continues during timer conversion after player retirement.
	game = make_game(false)
	game.transitions_enabled = true
	var intro = GameHandler.transitions.get_definition(&"level")
	intro.minimum_frames = 2
	for stage in intro.stages:
		stage.minimum_frames = 2
	add_child(game)
	while GameHandler.transitions.busy:
		await ticks()
	level = GameHandler.current_level
	ending = level.ending_presentation as FlagpoleEndingPresentation
	await grab(level, 40.0)
	assert(ending.grab_height == 152.0)
	assert(level.player.body.global_position.y < 43.0)
	# Keep this audio-tail scenario short; conversion cadence has dedicated coverage.
	GameHandler.time_remaining = 3
	await wait_phase(ending, FlagpoleEndingPresentation.Phase.WAIT)
	assert(level.player == null and GameHandler.current_player == null)
	assert(ending._audio != null and ending._audio.playing)
	assert(ending._pulse_audio != null and ending._pulse_audio.playing)
	SoundHandler.play_reward(&"timer_tick")
	assert(ending._pulse_audio.volume_linear == 0.0)
	assert(ending._audio.playing and ending._pulse_audio.playing)
	SoundHandler.stop_reward()
	assert(ending._pulse_audio.volume_linear == 1.0)
	while ending._audio.playing:
		assert(ending._wait_frames == 0)
		await ticks()
	var hold_start := ending._wait_frames
	assert(hold_start <= 1)
	await ticks(125 - hold_start)
	assert(GameHandler.current_level == level and not GameHandler.transitions.busy)
	for frame in range(900):
		await ticks()
		if GameHandler.flow == GameHandler.GameFlow.TITLE:
			assert(GameHandler.transitions.busy)
			assert(not game.get_node("UI/ScreenContainer/TitleScreen").visible)
			assert(not game.get_node("LevelContainer").visible)
			break
	assert(GameHandler.flow == GameHandler.GameFlow.TITLE)
	while GameHandler.transitions.busy:
		await ticks()
	assert(game.get_node("UI/ScreenContainer/TitleScreen").visible)
	game.free()
	await ticks(3)
	# Cancellation after player retirement restores a usable run and invalidates callbacks.
	game = make_game(true)
	add_child(game)
	level = GameHandler.current_level
	ending = level.ending_presentation as FlagpoleEndingPresentation
	await grab(level, 190.0)
	await wait_phase(ending, FlagpoleEndingPresentation.Phase.SCORE)
	await preload("res://tests/fixtures/pause_check.gd").check(level)
	var stale := ending.score_step.current_ticket
	var cancelled_popup: WeakRef = weakref(ending._score_popup)
	level.cancel_ending()
	ending.score_step.complete(stale)
	await ticks(2)
	assert(cancelled_popup.get_ref() == null)
	assert(GameHandler.flow == GameHandler.GameFlow.PLAYING)
	assert(is_instance_valid(level.player) and not level.completion_in_progress)
	assert(not (get_viewport().get_camera_2d() as LevelCamera).is_scroll_locked())
	await grab(level, 120.0)
	await ticks(5)
	assert(ending.phase == FlagpoleEndingPresentation.Phase.DESCEND)
	assert(level.player.body.global_position.y < 190.0)
	level.cancel_ending()
	game.free()
	await ticks(3)
	# External replacement restores PLAYING and invalidates the old presentation.
	game = make_game(true)
	add_child(game)
	level = GameHandler.current_level
	await grab(level, 120.0)
	assert(GameHandler.load_level(load("res://scenes/levels/test_level.tscn")))
	await ticks(2)
	assert(GameHandler.flow == GameHandler.GameFlow.PLAYING)
	assert(GameHandler.current_level.has_started)
	game.free()
	await ticks(3)
	# Losing the source pole cancels instead of leaving a scripted state stuck.
	game = make_game(true)
	add_child(game)
	level = GameHandler.current_level
	await grab(level, 120.0)
	level.active_area.get_node("WorldObjects/flagpole_196_2").queue_free()
	await ticks(3)
	assert(GameHandler.flow == GameHandler.GameFlow.PLAYING and not level.completion_in_progress)
	assert(level.player.climb_state.controls_enabled)
	game.free()
	await ticks(3)
	# Sample a low accepted contact directly to isolate the descent cutoff.
	game = make_game(true)
	add_child(game)
	level = GameHandler.current_level
	ending = level.ending_presentation as FlagpoleEndingPresentation
	ending.flag_sound = null
	pole = level.active_area.get_node("WorldObjects/flagpole_196_2") as FlagpoleEntity
	player = level.player
	player.set_physics_process(false)
	var low_contact := pole.climb_bottom.global_position + Vector2(-7, 2)
	player.body.global_position = low_contact
	(get_viewport().get_camera_2d() as LevelCamera).snap_to_arrival(player.body)
	level.active_area.update_camera_activity()
	await ticks()
	player.body.global_position = low_contact
	player._try_attach_climbable(low_contact, low_contact)
	player.set_physics_process(true)
	assert(player.body.global_position.y == low_contact.y)
	await wait_phase(ending, FlagpoleEndingPresentation.Phase.DISMOUNT)
	assert(player.body.global_position.y == low_contact.y)
	assert(pole.get_node("Presentation/Flag").position == pole._flag_origin)
	game.free()
	await ticks(3)
	print(
		"PASS: level-owned flagpole descent/flag/dismount/walk, camera lock, timer/input gates, endpoint retirement, async score/fireworks gates, music wait, title return and cancelled cleanup."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func capture_phase(value: FlagpoleEndingPresentation.Phase) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for frame in range(3):
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"res://.godot/validation/ending-phase-%s.png" % value
	)
