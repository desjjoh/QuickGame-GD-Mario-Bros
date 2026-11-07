extends Node


func ticks(count: int = 1) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	for digit in range(10):
		assert(
			CastleFireworksStep.count_for_time(120 + digit) == [0, 1, 0, 3, 0, 0, 6, 0, 0, 0][digit]
		)
		assert(CastleFireworksStep.count_for_time(120 + digit, false) == 0)
	var castle := load("res://scenes/entities/castle/castle.tscn").instantiate() as CastleEntity
	castle.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(castle)
	var bursts: Array[int] = []
	castle.firework_finished.connect(func(): bursts.append(castle._fireworks_tick))
	for count in [0, 1, 3, 6]:
		bursts.clear()
		castle.begin_fireworks(count)
		assert(castle.fireworks_active == (count > 0))
		if count == 0:
			assert(castle.advance_fireworks())
			continue
		var total: int = 24 + 32 * (count - 1)
		for tick in range(1, total + 1):
			var done := castle.advance_fireworks()
			assert(done == (tick == total))
			var age := tick % 32
			if age < 24 and not done:
				assert(castle._firework.visible and castle._firework.frame == floori(age / 8.0))
				var offset: Vector2 = CastleEntity.BURST_POSITIONS[5 - castle._burst_index]
				assert(castle._firework.position == Vector2(32, 80) + offset - Vector2(4, 4))
			else:
				assert(not castle._firework.visible)
		assert(bursts.size() == count)
		for index in range(count):
			assert(bursts[index] == 24 + 32 * index)
		assert(castle.advance_fireworks() and bursts.size() == count)
	castle.begin_fireworks(6)
	castle.advance_fireworks()
	castle.cancel_fireworks()
	assert(not castle._firework.visible and castle.advance_fireworks())
	castle.queue_free()
	assert(is_equal_approx(SoundHandler.get_sound(&"fireworks").get_length(), 32.0 / 60.0))
	# Real ending: choose at doorway, convert timer, raise flag, run and pause bursts.
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	await ticks(3)
	var level: BaseLevel = GameHandler.current_level
	var ending := level.ending_presentation as FlagpoleEndingPresentation
	ending.flag_sound = null
	ending.music = null
	GameHandler.time_remaining = 12
	var pole := level.active_area.get_node("WorldObjects/flagpole_196_2") as FlagpoleEntity
	level.player.body.global_position = Vector2(pole.climb_top.global_position.x - 7, 190)
	level.player.body.velocity = Vector2.ZERO
	var camera := get_viewport().get_camera_2d() as LevelCamera
	camera.snap_to_arrival(level.player.body)
	level.active_area.update_camera_activity()
	for frame in range(400):
		await ticks()
		if ending.phase == FlagpoleEndingPresentation.Phase.WALK:
			break
	assert(ending.phase == FlagpoleEndingPresentation.Phase.WALK)
	# Distinguish doorway selection from the contact-time snapshot (12).
	GameHandler.time_remaining = 13
	for frame in range(400):
		await ticks()
		if ending.phase == FlagpoleEndingPresentation.Phase.FIREWORKS:
			break
	assert(ending.remaining_time_at_contact == 12)
	assert(ending.phase == FlagpoleEndingPresentation.Phase.FIREWORKS)
	var step := ending.fireworks_step as CastleFireworksStep
	assert(step.count == 3 and GameHandler.time_remaining == 0)
	castle = step.castle
	var score := GameHandler.player_status.score
	assert(GameHandler.request_pause_toggle())
	var elapsed := castle._fireworks_tick
	var burst_frame := castle._firework.frame
	await ticks(10)
	assert(castle._fireworks_tick == elapsed and castle._firework.frame == burst_frame)
	assert(GameHandler.player_status.score == score)
	assert(GameHandler.request_pause_toggle())
	for frame in range(100):
		await ticks()
		if ending.phase == FlagpoleEndingPresentation.Phase.WAIT:
			break
	assert(ending.phase == FlagpoleEndingPresentation.Phase.WAIT)
	assert(GameHandler.player_status.score == score + 1500)
	assert(not castle.fireworks_active and not castle._firework.visible)
	assert(SoundHandler._square_two.stream == SoundHandler.get_sound(&"fireworks"))
	# Cancellation invalidates the adapter and cannot award an unfinished burst.
	step.count = 6
	step.begin()
	await ticks(4)
	step.cancel()
	var cancelled_score := GameHandler.player_status.score
	await ticks(30)
	assert(not castle.fireworks_active and not castle._firework.visible)
	assert(GameHandler.player_status.score == cancelled_score)
	game.queue_free()
	await ticks(2)
	print("fireworks_test: PASS")
	get_tree().quit()
