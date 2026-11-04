extends Node

signal step_finished
var pending: Callable


func _physics_process(_delta: float) -> void:
	if pending.is_valid():
		var callback := pending
		pending = Callable()
		callback.call()
		step_finished.emit()


func step_player(player: BasePlayer, direction: float, run: bool, jump: bool = false) -> void:
	pending = func():
		ControllerHandler.input_left = maxf(-direction, 0.0)
		ControllerHandler.input_right = maxf(direction, 0.0)
		ControllerHandler.input_secondary = run
		ControllerHandler.input_primary = jump
		ControllerHandler.input_primary_just_pressed = jump
		player._physics_process(1.0 / 60.0)
	await step_finished


func make_game() -> Node:
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	game.start_with_title = false
	game.transitions_enabled = false
	var fixture := load("res://scenes/levels/worlds/world 1/1-1.tscn").instantiate() as BaseLevel
	fixture.keep_player_on_screen = false
	fixture.fall_death_enabled = false
	fixture.get_node("Areas/MainArea/Camera2D").follow_enabled = false
	fixture.get_node("Areas/MainArea/Layouts/EntityLayout").clear()
	var ground := fixture.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
	ground.clear()
	for x in range(64):
		ground.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
	fixture.get_node("Players/PlayerSpawn").position = Vector2(256, 208)
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area, true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	game.initial_level = packed
	return game


func _ready() -> void:
	process_physics_priority = 200
	ControllerHandler.enabled = false
	for direction in [-1.0, 1.0]:
		var game := make_game()
		add_child(game)
		var player := GameHandler.current_player
		player.set_physics_process(false)
		for frame in range(3):
			await step_player(player, 0.0, false)
		assert(player.body.is_on_floor())
		player.face_direction(direction)
		# Idle -> Move calls preparation twice but never decrements twice.
		await step_player(player, direction, true)
		assert(
			(
				player.state_machine.current_state is MarioMoveState
				and player.run_action.remaining_ticks == 10
			)
		)
		await step_player(player, direction, false)
		assert(player.run_action.remaining_ticks == 9)
		player.body.velocity.x = direction * 150.0
		await step_player(player, direction, true)
		for released_tick in range(1, 11):
			var origin := player.body.global_position.x
			await step_player(player, direction, false)
			var expected := 150.0 if released_tick < 10 else 90.0
			assert(player.run_action.remaining_ticks == 10 - released_tick)
			assert(
				is_equal_approx(player.body.velocity.x, direction * expected),
				"Run release tick %s must match reference cap." % released_tick
			)
			assert(
				absf(player.body.global_position.x - origin - direction * expected / 60.0) < 0.1,
				(
					"dir=%s tick=%s origin=%s x=%s speed=%s floor=%s"
					% [
						direction,
						released_tick,
						origin,
						player.body.global_position.x,
						player.body.velocity,
						player.body.is_on_floor()
					]
				)
			)
		# Re-press before expiry reloads the timer without a walk-speed tick.
		player.body.velocity.x = direction * 150.0
		await step_player(player, direction, true)
		for frame in range(8):
			await step_player(player, direction, false)
		await step_player(player, direction, true)
		assert(player.run_action.remaining_ticks == 10 and absf(player.body.velocity.x) == 150.0)
		# Both buttons released: brake gradually, never clamp to the walk cap.
		await step_player(player, 0.0, false)
		assert(absf(player.body.velocity.x) > 90.0 and absf(player.body.velocity.x) < 150.0)
		# Release movement first: B must not choose a stronger neutral brake.
		for held_run in [true, false]:
			player.run_action.running_history = true
			player.body.velocity.x = direction * 150.0
			await step_player(player, 0.0, held_run)
			assert(is_equal_approx(player.body.velocity.x, direction * (150.0 - 182.8125 / 60.0)))
			# Latched friction persists below the instantaneous fast threshold.
			player.body.velocity.x = direction * 80.0
			await step_player(player, 0.0, held_run)
			assert(is_equal_approx(player.body.velocity.x, direction * (80.0 - 182.8125 / 60.0)))
		player.run_action.running_history = false
		player.body.velocity.x = direction * 80.0
		await step_player(player, 0.0, true)
		assert(is_equal_approx(player.body.velocity.x, direction * (80.0 - 133.59375 / 60.0)))
		# Opposite direction enters Slide; the directional clamp must not replace it.
		player.body.velocity.x = direction * 150.0
		await step_player(player, direction, true)
		await step_player(player, -direction, false)
		assert(player.state_machine.current_state is MarioSlideState)
		assert(player.body.velocity.x * direction > 90.0)
		player.state_machine.change_state(player.state_machine.get_state(&"Move"))
		player.body.velocity.x = direction * 150.0
		await step_player(player, direction, true)
		# A higher-priority environment cap stays authoritative.
		player.motion_values.set_modifier(&"level", {&"max_speed": 60.0}, 200)
		await step_player(player, direction, true)
		assert(absf(player.body.velocity.x) == 60.0)
		player.motion_values.remove_modifier(&"level")
		player.body.velocity.x = direction * 150.0
		await step_player(player, direction, true)
		for frame in range(9):
			await step_player(player, direction, false)
		# Jump on the expiry tick: air movement preserves the fast takeoff.
		await step_player(player, direction, false, true)
		assert(
			(
				player.run_action.remaining_ticks == 0
				and player.state_machine.current_state is MarioJumpState
			)
		)
		assert(absf(player.body.velocity.x) == 150.0)
		for frame in range(12):
			await step_player(player, direction, false)
		assert(not player.body.is_on_floor() and absf(player.body.velocity.x) == 150.0)
		game.free()
		await get_tree().process_frame
	ControllerHandler.enabled = true
	ControllerHandler.input_primary_just_pressed = false
	await get_tree().create_timer(0.15).timeout
	print(
		"PASS: nine retained ticks then tick-ten walk clamp in both directions, re-press, neutral braking, skidding, higher-priority caps, once-only handoff timing and expiry-tick jump momentum."
	)
	get_tree().quit()
