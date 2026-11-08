extends Node

signal state_tick_done
var _pending_tick: Callable


func _physics_process(_delta: float) -> void:
	if _pending_tick.is_valid():
		var callback := _pending_tick
		_pending_tick = Callable()
		callback.call()
		state_tick_done.emit()


func _ready() -> void:
	call_deferred("run_checks")


func tick(count: int) -> void:
	for index in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame


func run_checks() -> void:
	# Exercise the exact grounded-state tick, without input polling races.
	for state_name in [&"Idle", &"Move", &"Slide"]:
		for run_pressed in [false, true]:
			var trial: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
			var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
			fixture.get_node("Areas/MainArea/Layouts/EntityLayout").clear()
			var floor := fixture.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
			floor.clear()
			for x in range(16):
				floor.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
			fixture.get_node("Players/PlayerSpawn").position = Vector2(40, 208)
			var packed := PackedScene.new()
			for area in fixture.get_node("Areas").get_children():
				fixture.set_editable_instance(area, true)
			assert(packed.pack(fixture) == OK)
			fixture.free()
			trial.initial_level = packed
			get_tree().root.add_child(trial)
			await tick(5)
			var mario := GameHandler.current_player
			mario.set_physics_process(false)
			await get_tree().physics_frame
			mario.body.velocity.x = 60.0
			mario.state_machine.change_state(mario.state_machine.get_state(state_name))
			# Previous tick had the opposite Run value.
			mario.run_action.apply(mario.motion_values, not run_pressed)
			var takeoff_origin := mario.body.global_position
			_pending_tick = func():
				ControllerHandler.input_secondary = run_pressed
				ControllerHandler.input_primary_just_pressed = true
				mario.state_machine.process_physics(1.0 / 60.0)
			await state_tick_done
			assert(mario.state_machine.current_state is MarioJumpState)
			assert(
				mario.body.global_position.x > takeoff_origin.x,
				"Takeoff must not skip horizontal movement from %s" % state_name
			)
			assert(
				(
					absf(
						(
							(mario.body.global_position.x - takeoff_origin.x)
							- mario.body.velocity.x / 60.0
						)
					)
					< 0.1
				),
				"Takeoff must consume exactly one movement tick from %s" % state_name
			)
			assert(
				mario.body.global_position.y < takeoff_origin.y,
				"Takeoff must move upward immediately from %s" % state_name
			)
			# Air's modifier masks Run; remove it to inspect the refreshed value.
			mario.air_movement.end(mario.motion_values)
			assert(
				mario.motion_values.max_speed == (150.0 if run_pressed else 90.0),
				"Run must refresh before takeoff from %s" % state_name
			)
			ControllerHandler.input_primary_just_pressed = false
			ControllerHandler.input_secondary = false
			trial.free()
	var action := AirMovementComponent.new()
	var body := CharacterBody2D.new()
	var values := MotionValues.new()
	values.body = body
	for direction in [-1.0, 1.0]:
		body.velocity = Vector2(direction * 90.0, -100)
		action.capture(values, -direction)
		action.begin(values, -direction)
		assert(is_equal_approx(values.acceleration, 267.1875))
		action.apply(values, -direction, 1.0 / 60.0)
		assert(is_equal_approx(body.velocity.x, direction * 85.546875))
		assert(body.velocity.y == -100.0)
		var coast := body.velocity.x
		action.apply(values, 0.0, 1.0 / 60.0)
		assert(body.velocity.x == coast and values.deceleration == 0.0)
		action.end(values)
		body.velocity.x = direction * 150.0
		action.capture(values, -direction)
		action.begin(values, -direction)
		assert(is_equal_approx(values.acceleration, 400.78125))
		body.velocity.x = direction * 80.0
		action.update_profile(values)
		assert(is_equal_approx(values.acceleration, 365.625))
		body.velocity.x = -direction * 10.0
		action.update_profile(values)
		assert(is_equal_approx(values.acceleration, 182.8125))
		action.end(values)
	# Low-speed takeoff retains the ground running latch. Neutral air coasts,
	# opposite input brakes across zero, then facing mismatch doubles friction.
	for direction in [-1.0, 1.0]:
		body.velocity.x = direction * 80.0
		action.capture(values, direction, true)
		action.begin(values, direction)
		action.apply(values, 0.0, 1.0 / 60.0)
		assert(body.velocity.x == direction * 80.0)
		action.apply(values, -direction, 1.0 / 60.0)
		assert(is_equal_approx(body.velocity.x, direction * (80.0 - 182.8125 / 60.0)))
		body.velocity.x = -direction * 10.0
		action.apply(values, -direction, 1.0 / 60.0)
		assert(is_equal_approx(body.velocity.x, -direction * (10.0 + 365.625 / 60.0)))
		action.end(values)
	assert(values.acceleration == values.base_acceleration)
	values.free()
	body.free()
	action.free()
	for direction in [-1.0, 1.0]:
		var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
		get_tree().root.add_child(game)
		preload("res://tests/test_floor.gd").extend_floor(game)
		var player := GameHandler.current_player
		var forward: StringName = (
			ControllerHandler.right_action if direction > 0.0 else ControllerHandler.left_action
		)
		var backward: StringName = (
			ControllerHandler.left_action if direction > 0.0 else ControllerHandler.right_action
		)
		Input.action_press(forward)
		Input.action_press(ControllerHandler.secondary_action)
		await tick(65)
		Input.action_release(forward)
		Input.action_press(backward)
		await tick(2)
		assert(player.state_machine.current_state is MarioSlideState)
		var takeoff_speed := absf(player.body.velocity.x)
		Input.action_press(ControllerHandler.primary_action)
		await tick(3)
		assert(player.state_machine.current_state is MarioJumpState)
		assert(absf(player.body.velocity.x) < takeoff_speed)
		assert(is_equal_approx(player.motion_values.acceleration, 400.78125))
		assert(player.sprite.flip_h == (direction > 0.0))
		Input.action_release(backward)
		await tick(2)
		var coast := player.body.velocity.x
		await tick(3)
		assert(is_equal_approx(player.body.velocity.x, coast))
		Input.action_release(ControllerHandler.primary_action)
		await tick(90)
		assert(player.body.is_on_floor())
		assert(player.motion_values.acceleration == player.run_action.history_acceleration)
		assert(player.motion_values.deceleration == player.run_action.history_acceleration)
		Input.action_release(ControllerHandler.secondary_action)
		game.free()
	print(
		"PASS: air rates, facing-based braking, fast history, neutral coasting, skid-jump capture in both directions, and landing cleanup."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
