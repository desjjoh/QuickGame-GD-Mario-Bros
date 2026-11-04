extends Node


func _ready() -> void:
	call_deferred("run_checks")


func tick(count: int) -> void:
	for index in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame


func run_checks() -> void:
	var action := SlideAction.new()
	var run := RunAction.new()
	var values := MotionValues.new()
	var body := CharacterBody2D.new()
	values.body = body
	body.velocity = Vector2(90.0, 7.0)
	assert(action.can_start(body, -1.0))
	assert(not action.can_start(body, 0.0) and not action.can_start(body, 1.0))
	action.begin(values)
	assert(is_equal_approx(values.acceleration * values.reversal_multiplier, 267.1875))
	assert(not action.apply(values, 1.0 / 60.0))
	assert(is_equal_approx(body.velocity.x, 85.546875) and body.velocity.y == 7.0)
	action.end(values)
	body.velocity.x = 150.0
	run.apply(values, true)
	action.begin(values)
	assert(is_equal_approx(values.acceleration * values.reversal_multiplier, 365.625))
	assert(values.max_speed == 90.0 and body.velocity.x == 150.0)
	action.apply(values, 1.0 / 60.0)
	assert(is_equal_approx(body.velocity.x, 143.90625))
	action.end(values)
	assert(values.max_speed == 150.0)
	body.velocity.x = -90.0
	action.begin(values)
	action.apply(values, 1.0 / 60.0)
	assert(is_equal_approx(body.velocity.x, -85.546875))
	body.velocity.x = 42.0
	assert(action.apply(values, 1.0 / 60.0))
	assert(body.velocity == Vector2(0, 7))
	body.velocity.x = 40.0
	assert(not action.can_start(body, -1.0))
	body.velocity.x = 90.0
	values.set_modifier(&"level", {&"acceleration": 50.0}, 400)
	assert(is_equal_approx(values.acceleration, 50.0))
	action.end(values)
	assert(values.acceleration == 50.0)
	values.remove_modifier(&"level")
	assert(values.acceleration == run.acceleration)
	body.free()
	values.free()
	run.free()
	action.free()
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	get_tree().root.add_child(game)
	preload("res://tests/test_floor.gd").extend_floor(game)
	var player := GameHandler.current_player
	Input.action_press(ControllerHandler.right_action)
	Input.action_press(ControllerHandler.secondary_action)
	await tick(65)
	assert(is_equal_approx(player.body.velocity.x, 150.0))
	Input.action_release(ControllerHandler.right_action)
	Input.action_press(ControllerHandler.left_action)
	await tick(2)
	assert(player.state_machine.current_state is MarioSlideState)
	assert(
		(
			player.sprite.texture.resource_path
			== "res://assets/player/mario (small)/mario-small-slide.png"
		)
	)
	assert(player.body.velocity.x > 0.0 and player.body.velocity.x < 150.0)
	assert(player.sprite.flip_h)
	assert(is_equal_approx(player.motion_values.acceleration, 182.8125))
	# Cancelling the reversal exits Slide and removes only its modifier.
	Input.action_release(ControllerHandler.left_action)
	Input.action_press(ControllerHandler.right_action)
	await tick(2)
	assert(player.state_machine.current_state is MarioMoveState)
	assert(
		player.animation_player.current_animation == "walk" and player.animation_player.is_playing()
	)
	assert(is_equal_approx(player.motion_values.acceleration, player.run_action.acceleration))
	await tick(20)
	Input.action_release(ControllerHandler.right_action)
	Input.action_press(ControllerHandler.left_action)
	await tick(2)
	assert(player.state_machine.current_state is MarioSlideState)
	await tick(60)
	assert(player.state_machine.current_state is MarioMoveState)
	assert(player.body.velocity.x < 0.0)
	assert(player.motion_values.max_speed == 150.0)
	Input.action_release(ControllerHandler.left_action)
	Input.action_release(ControllerHandler.secondary_action)
	await tick(90)
	assert(player.state_machine.current_state is MarioIdleState)
	assert(
		(
			player.sprite.texture.resource_path
			== "res://assets/player/mario (small)/mario-small-idle.png"
		)
	)
	assert(player.motion_values.acceleration == player.run_action.history_acceleration)
	# Releasing direction, with or without Run held, must retain the skid pose
	# and modifier until stopping, in both travel directions and speed modes.
	for travel_direction in [1.0, -1.0]:
		for running in [false, true]:
			for release_run in [false, true]:
				# Keep each case on the flat test surface; do not re-enter a tile
				# side from offscreen while testing a horizontal-only controller.
				player.body.global_position = Vector2(128, 208)
				var forward: StringName = (
					ControllerHandler.right_action
					if travel_direction > 0.0
					else ControllerHandler.left_action
				)
				var backward: StringName = (
					ControllerHandler.left_action
					if travel_direction > 0.0
					else ControllerHandler.right_action
				)
				Input.action_press(forward)
				if running:
					Input.action_press(ControllerHandler.secondary_action)
				await tick(65)
				Input.action_release(forward)
				Input.action_press(backward)
				await tick(2)
				assert(player.state_machine.current_state is MarioSlideState)
				var skid_facing := player.sprite.flip_h
				var previous_speed := absf(player.body.velocity.x)
				Input.action_release(backward)
				if release_run:
					Input.action_release(ControllerHandler.secondary_action)
				await tick(2)
				assert(player.state_machine.current_state is MarioSlideState)
				assert(
					(
						player.sprite.texture.resource_path
						== "res://assets/player/mario (small)/mario-small-slide.png"
					)
				)
				assert(player.sprite.flip_h == skid_facing)
				assert(absf(player.body.velocity.x) < previous_speed)
				while not is_zero_approx(player.body.velocity.x):
					assert(player.state_machine.current_state is MarioSlideState)
					await tick(1)
				assert(player.state_machine.current_state is MarioIdleState)
				assert(
					(
						player.sprite.texture.resource_path
						== "res://assets/player/mario (small)/mario-small-idle.png"
					)
				)
				assert(not player.motion_values._modifiers.has(&"slide"))
				# The exit tick retains the pre-stop facing-mismatch profile;
				# Idle selects the stationary neutral profile on its next tick.
				await tick(2)
				assert(
					(
						player.motion_values.acceleration
						== (
							player.run_action.history_acceleration
							if player.run_action.running_history
							else player.run_action.neutral_acceleration
						)
					)
				)
				Input.action_release(ControllerHandler.secondary_action)
				await tick(2)
	game.free()
	# Let queued sound deletions and the audio-server cleanup finish before quit.
	await tick(6)
	print(
		"PASS: skid rates, cancellation, release-to-stop skid retention in both directions and speed modes, sprite/facing retention, and modifier cleanup."
	)
	get_tree().quit()
