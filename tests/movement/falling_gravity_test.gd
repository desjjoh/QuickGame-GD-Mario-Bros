extends Node
signal tick_finished


func _physics_process(_delta: float) -> void:
	tick_finished.emit()


func tick() -> void:
	await tick_finished


func _ready() -> void:
	process_physics_priority = 200
	var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
	add_child(game)
	var level := GameHandler.current_level
	var player := level.player
	assert(player.jump_action.falling_gravity == 562.5)
	player.jump_action.sound_effect = null
	player.set_physics_process(false)
	level.set_physics_process(false)
	level.keep_player_on_screen = false
	ControllerHandler.set_physics_process(false)
	ControllerHandler.input_left = 0
	ControllerHandler.input_right = 0
	ControllerHandler.input_primary = false
	ControllerHandler.input_primary_just_pressed = false
	for frame in range(3):
		await tick()
	for profile in [
		[150.0, 2025.0], [0.0, 1575.0], [60.0, 1350.0], [33.75, 1575.0], [93.75, 2025.0]
	]:
		player.state_machine.stop(false)
		player.body.global_position = Vector2(40, 207.9)
		player.body.velocity = Vector2(0, 60)
		await tick()
		player.move_body()
		assert(player.body.is_on_floor())
		player.body.velocity.x = profile[0]
		assert(player.jump_action.begin(player.motion_values))
		assert(player.jump_action.falling_gravity == profile[1])
		# Jump exit removes its live modifier, not the retained falling profile.
		player.jump_action.end(player.motion_values)
		assert(player.motion_values.gravity == player.motion_values.base_gravity)
		player.body.global_position = Vector2(40, 100)
		player.body.velocity = Vector2.ZERO
		await tick()
		player.body.move_and_slide()
		player.body.velocity.x = 150
		assert(player.state_machine.change_state(player.state_machine.get_state(&"Move")))
		await tick()
		player.state_machine.process_physics(1.0 / 60.0)
		assert(player.motion_values.gravity == profile[1])
		assert(is_equal_approx(player.body.velocity.y, profile[1] / 60.0))
		assert(player.body.velocity.x == 150.0)
		assert(is_equal_approx(player.body.global_position.y, 100.0))
		# A higher-priority effect and weight still control effective gravity.
		player.motion_values.set_modifier(&"test_override", {&"gravity": 1000.0}, 400)
		player.motion_values.base_weight = 2
		var previous_y := player.body.velocity.y
		await tick()
		player.state_machine.process_physics(1.0 / 60.0)
		assert(is_equal_approx(player.body.velocity.y, previous_y + 2000.0 / 60.0))
		player.motion_values.remove_modifier(&"test_override")
		player.motion_values.base_weight = 1
		player.state_machine.stop(false)
		assert(player.motion_values.gravity == player.motion_values.base_gravity)
		assert(player.jump_action.falling_gravity == profile[1])
	# A later jump replaces the fast profile; initialization restores the entrance value.
	player.jump_action.reset_falling_gravity()
	assert(player.jump_action.falling_gravity == 562.5)
	player.body.global_position = Vector2(40, 100)
	player.body.velocity = Vector2.ZERO
	await tick()
	player.body.move_and_slide()
	assert(player.state_machine.change_state(player.state_machine.get_state(&"Move")))
	await tick()
	player.state_machine.process_physics(1.0 / 60.0)
	assert(player.motion_values.gravity == 562.5)
	assert(is_equal_approx(player.body.velocity.y, 9.375))
	player.state_machine.stop(false)
	assert(player.motion_values.gravity == player.motion_values.base_gravity)
	game.free()
	ControllerHandler.set_physics_process(true)
	await get_tree().process_frame
	print(
		"PASS: entrance gravity, five takeoff profiles, retained fall selection, passive-fall application, horizontal coasting, weight/override priority and modifier cleanup."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
