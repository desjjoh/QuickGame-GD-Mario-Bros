extends Node


func _ready() -> void:
	call_deferred("run_checks")


func tick(count: int) -> void:
	for index in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame


func run_checks() -> void:
	var cadence := WalkAnimationComponent.new()
	for direction in [-1.0, 1.0]:
		assert(cadence.get_frame_ticks(0.0) == 7)
		assert(cadence.get_frame_ticks(direction * 52.49) == 7)
		assert(cadence.get_frame_ticks(direction * 52.5) == 4)
		assert(cadence.get_frame_ticks(direction * 104.99) == 4)
		assert(cadence.get_frame_ticks(direction * 105.0) == 2)
	cadence.free()
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	get_tree().root.add_child(game)
	preload("res://tests/test_floor.gd").extend_floor(game)
	var mario := GameHandler.current_player as Mario
	var move_state := mario.state_machine.get_state(&"Move")
	assert(move_state.animation_name == &"walk", "Mario Move must select walk in its saved scene configuration.")
	assert(not move_state.stop_animation_on_enter)
	for state_name in [&"Idle", &"Slide"]:
		var static_state := mario.state_machine.get_state(state_name)
		assert(static_state.sprite_texture != null and static_state.stop_animation_on_enter,
			"Mario's static states must stop playback and restore their assigned texture.")
	var animation := mario.animation_player.get_animation(&"walk")
	assert(animation.loop_mode == Animation.LOOP_LINEAR)
	assert(animation.track_get_key_count(0) == 3)
	assert(animation.track_get_path(0) == NodePath("Sprite2D:texture"))
	assert(mario.sprite.texture.resource_path.ends_with("mario-small-idle.png"))
	# Inspect the authored resource deterministically without automatic playback.
	await tick(5)
	assert(mario.body.is_on_floor())
	mario.set_physics_process(false)
	mario.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	mario.state_machine.change_state(mario.state_machine.get_state(&"Move"))
	assert(mario.sprite.texture.resource_path.ends_with("mario-small-walk-1.png"))
	mario.animation_player.advance(7.0 / 60.0 + 0.000001)
	assert(mario.sprite.texture.resource_path.ends_with("mario-small-walk-2.png"))
	mario.animation_player.advance(7.0 / 60.0)
	assert(mario.sprite.texture.resource_path.ends_with("mario-small-walk-3.png"))
	mario.animation_player.advance(7.0 / 60.0)
	assert(mario.sprite.texture.resource_path.ends_with("mario-small-walk-1.png"))
	mario.state_machine.change_state(mario.state_machine.get_state(&"Idle"))
	assert(not mario.animation_player.is_playing() and mario.animation_player.speed_scale == 1.0)
	assert(mario.sprite.texture.resource_path.ends_with("mario-small-idle.png"))
	mario.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	mario.set_physics_process(true)
	Input.action_press(ControllerHandler.right_action)
	await tick(60)
	assert(mario.state_machine.current_state is MarioMoveState)
	assert(is_equal_approx(mario.animation_player.speed_scale, 1.75))
	var observed: Dictionary[String, bool] = {}
	for index in range(20):
		await tick(1)
		observed[mario.sprite.texture.resource_path] = true
	assert(observed.size() == 3, "All three supplied poses must play in the live loop.")
	Input.action_press(ControllerHandler.secondary_action)
	await tick(2)
	assert(ControllerHandler.input_secondary and mario.body.velocity.x < 105.0)
	assert(is_equal_approx(mario.animation_player.speed_scale, 1.75), "Run input alone must not select fast cadence.")
	await tick(25)
	assert(is_equal_approx(mario.animation_player.speed_scale, 3.5))
	Input.action_release(ControllerHandler.right_action)
	await tick(16)
	assert(mario.body.velocity.x < 105.0 and mario.body.velocity.x >= 52.5)
	assert(is_equal_approx(mario.animation_player.speed_scale, 1.75))
	await tick(40)
	assert(mario.state_machine.current_state is MarioIdleState)
	assert(not mario.animation_player.is_playing())
	assert(mario.sprite.texture.resource_path.ends_with("mario-small-idle.png"))
	Input.action_release(ControllerHandler.secondary_action)
	game.free()
	print("PASS: three-pose loop, exact cadence boundaries in both directions, velocity-based speed changes, live frame progression, braking slowdown, and static Idle restoration.")
	get_tree().quit()

