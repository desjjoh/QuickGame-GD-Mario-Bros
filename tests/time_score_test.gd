extends Node
signal tick_finished


func _physics_process(_delta: float) -> void:
	tick_finished.emit()


func ticks(count: int = 1) -> void:
	for frame in range(count):
		await tick_finished


func make_game(timer_enabled: bool = true) -> Node:
	var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	fixture.timer_enabled = timer_enabled
	var ending := fixture.ending_presentation as FlagpoleEndingPresentation
	fixture.set_editable_instance(ending, true)
	ending.get_node("Fireworks").set_script(load("res://tests/fixtures/manual_ending_step.gd"))
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area, true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
	game.stages.assign([packed])
	add_child(game)
	GameHandler.current_level.ending_presentation.flag_sound = null
	GameHandler.current_level.ending_presentation.music = null
	return game


func reach_score(level: BaseLevel) -> void:
	var pole := level.active_area.get_node("WorldObjects/flagpole_196_2") as FlagpoleEntity
	level.player.body.global_position = Vector2(pole.climb_top.global_position.x - 7, 190)
	level.player.body.velocity = Vector2.ZERO
	var camera := get_viewport().get_camera_2d() as LevelCamera
	camera.snap_to_arrival(level.player.body)
	level.active_area.update_camera_activity()
	for frame in range(400):
		await ticks()
		if (
			level.ending_presentation.phase == FlagpoleEndingPresentation.Phase.SCORE
			or level.ending_presentation.phase == FlagpoleEndingPresentation.Phase.RAISE_FLAG
		):
			return
	assert(false, "Ending never reached timer conversion.")


func _ready() -> void:
	process_physics_priority = 200
	var game := make_game()
	var level := GameHandler.current_level
	var ending := level.ending_presentation as FlagpoleEndingPresentation
	var step := ending.score_step as TimeScoreStep
	var completed: Array[int] = []
	step.finished.connect(func(ticket: int): completed.append(ticket))
	GameHandler.time_remaining = 13
	GameHandler.set_score(900)
	await reach_score(level)
	assert(ending.phase == FlagpoleEndingPresentation.Phase.SCORE)
	assert(ending.remaining_time_at_contact == 13)
	assert(GameHandler.time_remaining == 13 and completed.is_empty())
	assert(level.player == null)
	var ticket := step.current_ticket
	var hud := game.get_node("UI/HUD")
	for frame in range(13):
		await ticks()
		assert(GameHandler.time_remaining == 12 - frame)
		assert(GameHandler.player_status.score == 1050 + 50 * frame)
		assert(hud.get_node("TimeValue").text == "%03d" % (12 - frame))
		assert(hud.get_node("Score").text == " %06d" % (1050 + 50 * frame))
		assert(ending.phase == FlagpoleEndingPresentation.Phase.SCORE)
	assert(SoundHandler._square_two.stream == SoundHandler.get_sound(&"timer_tick"))
	assert(completed.is_empty())
	await ticks()
	assert(completed == [ticket])
	assert(ending.phase == FlagpoleEndingPresentation.Phase.RAISE_FLAG)
	assert(ending.remaining_time_at_contact == 13 and GameHandler.time_remaining == 0)
	assert(GameHandler.player_status.score == 1650)
	await ticks(4)
	assert(GameHandler.player_status.score == 1650 and completed.size() == 1)
	assert(not step.is_physics_processing() and step.get_child_count() == 0)
	GameHandler.set_top_score(1000)
	await ticks(28)
	assert(ending.phase == FlagpoleEndingPresentation.Phase.FIREWORKS)
	ending.fireworks_step.complete(ending.fireworks_step.current_ticket)
	await ticks(127)
	assert(GameHandler.flow == GameHandler.GameFlow.TITLE)
	assert(GameHandler.top_score == 1650 and GameHandler.player_status.score == 0)
	assert(game.get_node("UI/ScreenContainer/TitleScreen/TopScore").text == "TOP- 001650")
	game.free()
	await ticks(2)
	# Zero and disabled timers skip conversion, even if a disabled timer stores time.
	for enabled in [true, false]:
		game = make_game(enabled)
		level = GameHandler.current_level
		GameHandler.time_remaining = 0 if enabled else 400
		GameHandler.set_score(321)
		await reach_score(level)
		assert(level.ending_presentation.phase == FlagpoleEndingPresentation.Phase.RAISE_FLAG)
		assert(GameHandler.player_status.score == 421)
		assert(GameHandler.time_remaining == (0 if enabled else 400))
		game.free()
		await ticks(2)
	# Cancellation stops future units and stale completion cannot advance the ending.
	game = make_game()
	level = GameHandler.current_level
	GameHandler.time_remaining = 20
	GameHandler.set_score(0)
	await reach_score(level)
	ending = level.ending_presentation as FlagpoleEndingPresentation
	step = ending.score_step as TimeScoreStep
	await ticks(2)
	assert(GameHandler.player_status.score == 200 and GameHandler.time_remaining == 18)
	ticket = step.current_ticket
	level.cancel_ending()
	step.complete(ticket)
	await ticks(3)
	assert(not step.active and not step.is_physics_processing())
	assert(GameHandler.player_status.score == 200 and GameHandler.time_remaining == 18)
	assert(GameHandler.flow == GameHandler.GameFlow.PLAYING)
	game.free()
	await ticks(2)
	# An observer can replace the level while the timer setter emits its signal.
	game = make_game()
	level = GameHandler.current_level
	GameHandler.time_remaining = 3
	GameHandler.set_score(777)
	await reach_score(level)
	var replace_level := func(key: StringName, _value: Variant):
		if key == &"time_remaining":
			assert(GameHandler.load_level(load("res://scenes/levels/test_level.tscn")))
	GameHandler.session_value_changed.connect(replace_level, CONNECT_ONE_SHOT)
	await ticks(2)
	assert(GameHandler.current_level != level)
	assert(GameHandler.time_remaining == 400 and GameHandler.player_status.score == 877)
	game.free()
	await ticks(2)
	# Score saturation still drains the timer and completes exactly once.
	game = make_game()
	level = GameHandler.current_level
	GameHandler.time_remaining = 2
	GameHandler.set_score(999980)
	await reach_score(level)
	await ticks(3)
	assert(GameHandler.time_remaining == 0 and GameHandler.player_status.score == 999999)
	assert(level.ending_presentation.phase == FlagpoleEndingPresentation.Phase.RAISE_FLAG)
	game.free()
	await ticks(2)
	print(
		"PASS: 50 points per timer unit per tick, HUD updates, preserved contact time, zero/disabled skip, completion gate, cancellation, stale callbacks, reentrant level replacement and score saturation; synthesized counting audio uses the shared voice."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
