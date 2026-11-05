extends Node

signal physics_step_finished
var time_values: Array[int] = []
var transition_kinds: Array[StringName] = []


func _physics_process(_delta: float) -> void:
	physics_step_finished.emit()


func ticks(count: int = 1) -> void:
	for frame in range(count):
		await physics_step_finished


func record_value(key: StringName, value: Variant) -> void:
	if key == &"time_remaining":
		time_values.append(int(value))


func record_transition(_id: int, kind: StringName) -> void:
	transition_kinds.append(kind)


func wait_idle() -> void:
	for frame in range(400):
		if not GameHandler.transitions.busy:
			return
		await ticks()
	assert(false, "Timer transition did not finish.")


func wait_phase(phase: StringName) -> void:
	for frame in range(300):
		if GameHandler.transitions.busy and GameHandler.transitions.phase == phase:
			return
		await ticks()
	assert(false, "Expected timer presentation phase was not reached.")


func make_game(starting: int, animated: bool) -> Node:
	var game: Node = load("res://scenes/main/game.tscn").instantiate()
	var fixture := game.initial_level.instantiate() as BaseLevel
	fixture.starting_time = starting
	fixture.death_sound = null
	fixture.death_fallback_delay = 0.05
	fixture.get_node("Areas/MainArea/Layouts/EntityLayout").clear()
	var ground := fixture.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
	ground.clear()
	for x in range(16):
		ground.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area, true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	assert(ResourceSaver.save(packed, "res://.godot/validation/timer-stage.tscn") == OK)
	game.initial_level = ResourceLoader.load(
		"res://.godot/validation/timer-stage.tscn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE
	)
	game.start_with_title = false
	game.transitions_enabled = animated
	return game


func _ready() -> void:
	process_physics_priority = 200
	var director: TransitionCoordinator = GameHandler.transitions
	var intro := director.get_definition(&"level")
	intro.minimum_frames = 2
	for stage in intro.stages:
		stage.minimum_frames = 2
	assert(director.get_definition(&"time_up").stages[0].minimum_frames == 147)
	# Keep final-life presentation fast; audio integration has independent tests.
	var silent_card: Control = load("res://scenes/ui/transitions/game_over.tscn").instantiate()
	silent_card.sound = null
	var silent_scene := PackedScene.new()
	assert(silent_scene.pack(silent_card) == OK)
	silent_card.free()
	var game_over := director.get_definition(&"game_over")
	game_over.minimum_frames = 2
	game_over.stages[0].scene = silent_scene
	for stage in game_over.stages:
		stage.minimum_frames = 2
	GameHandler.clear_session()
	GameHandler.session_value_changed.connect(record_value)
	director.started.connect(record_transition)
	await ticks(7)  # Startup must not depend on a global modulo boundary.
	var game := make_game(5, true)
	add_child(game)
	for frame in range(30):
		await ticks()
		if GameHandler.current_level != null:
			break
	var level := GameHandler.current_level
	assert(not level.has_started and GameHandler.time_remaining == 5)
	await wait_idle()
	assert(level.has_started and time_values == [5])
	assert(not level.on_level_start() and GameHandler.time_remaining == 5)
	await ticks(23)
	assert(GameHandler.time_remaining == 5)
	await ticks()
	assert(GameHandler.time_remaining == 4 and time_values == [5, 4])
	await ticks(5)
	var phase := level._timer_ticks_remaining
	var clock_before: int = GameHandler.animation_clock.tick_count
	level.transition_in_progress = true
	await ticks(40)
	assert(GameHandler.time_remaining == 4 and level._timer_ticks_remaining == phase)
	assert(GameHandler.animation_clock.tick_count == clock_before + 40)
	level.transition_in_progress = false
	await ticks(phase - 1)
	assert(GameHandler.time_remaining == 4)
	await ticks()
	assert(GameHandler.time_remaining == 3)
	# Area replacement must neither reinitialize nor re-arm the level timer.
	level.set_physics_process(false)
	assert(level.request_area_transfer(&"lower"))
	await ticks(3)
	await wait_idle()
	assert(GameHandler.time_remaining == 3 and level.has_started)
	assert(level.request_area_transfer(&"main", &"player_spawn"))
	await ticks(3)
	await wait_idle()
	assert(GameHandler.time_remaining == 3)
	game.free()
	await ticks(2)
	# Disabled TestLevel keeps TIME but hides only its numeric value.
	game = load("res://scenes/main/game.tscn").instantiate()
	game.initial_level = load("res://scenes/levels/test_level.tscn")
	game.start_with_title = false
	game.transitions_enabled = false
	add_child(game)
	var hud := game.get_node("UI/HUD")
	assert(GameHandler.current_level.has_started and not GameHandler.timer_enabled)
	assert(hud.get_node("TimeHeading").visible and not hud.get_node("TimeValue").visible)
	await ticks(60)
	assert(GameHandler.time_remaining == 400)
	game.free()
	await ticks(2)
	for final_attempt in [false, true]:
		GameHandler.clear_session()
		game = make_game(1, true)
		add_child(game)
		await wait_idle()
		level = GameHandler.current_level
		GameHandler.set_lives(0 if final_attempt else 1)
		GameHandler.set_player_form(PlayerStatus.PowerupForm.SUPER)
		transition_kinds.clear()
		await ticks(24)
		assert(GameHandler.time_remaining == 0 and not level.death_in_progress)
		await ticks(23)
		assert(not level.death_in_progress)
		await ticks()
		assert(level.death_in_progress and level.timer_expired)
		assert(level.death_reason == BaseLevel.DeathReason.TIMEOUT)
		assert(GameHandler.player_status.powerup_form == PlayerStatus.PowerupForm.SMALL)
		assert(level.player.state_machine.current_state is MarioDeadState)
		assert(GameHandler.player_status.lives == (-1 if final_attempt else 0))
		await wait_phase(&"time_up")
		assert(GameHandler.current_level == level and GameHandler.time_remaining == 0)
		assert(
			(
				(
					game
					. get_node("UI/ScreenContainer/TransitionScreen")
					. presentation
					. get_node("Message")
					. text
				)
				== "TIME UP"
			)
		)
		assert(game.get_node("UI/HUD/TimeValue").text == "000")
		var remaining := 147 - director.phase_frames
		await ticks(maxi(remaining - 1, 0))
		assert(director.phase == &"time_up")
		for frame in range(200):
			await ticks()
			if not director.busy and GameHandler.current_level != level:
				break
		assert(
			(
				transition_kinds
				== ([&"time_up", &"game_over"] if final_attempt else [&"time_up", &"level"])
			)
		)
		if final_attempt:
			assert(GameHandler.flow == GameHandler.GameFlow.TITLE)
			assert(GameHandler.player_status.lives == 2)
		else:
			assert(GameHandler.current_level.has_started)
			assert(GameHandler.time_remaining == 1)
			await ticks(23)
			assert(GameHandler.time_remaining == 1)
		game.free()
		await ticks(2)
	GameHandler.session_value_changed.disconnect(record_value)
	director.started.disconnect(record_transition)
	print(
		"PASS: single timer initialization, post-intro start/full 24 ticks, phase-preserving pauses/area travel, disabled HUD number, zero dwell, animated timeout and TIME UP before lives/game-over."
	)
	get_tree().quit()
