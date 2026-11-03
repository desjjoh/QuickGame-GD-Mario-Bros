extends Node
## Uses synthetic input through the real global handler and physics callbacks.


func _ready() -> void:
	call_deferred("run_checks")


func tick(count: int) -> void:
	for index in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame


func run_checks() -> void:
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	get_tree().root.add_child(game)
	preload("res://tests/test_floor.gd").extend_floor(game)
	var player: BasePlayer = GameHandler.current_player
	var initial_position := player.body.global_position
	Input.action_press(ControllerHandler.right_action)
	await tick(60)
	assert(player.state_machine.current_state is MarioMoveState)
	assert(player.body.global_position.x > initial_position.x)
	assert(absf(player.body.global_position.y - initial_position.y) < 0.2)
	assert(is_equal_approx(player.body.velocity.x, player.motion_values.max_speed))
	assert(not player.sprite.flip_h)
	var move := player.state_machine.current_state
	move.sprite_offset = Vector2(2, 0)
	Input.action_release(ControllerHandler.right_action)
	Input.action_press(ControllerHandler.left_action)
	await tick(45)
	assert(player.body.velocity.x < 0.0 and player.sprite.flip_h)
	assert(player.sprite.offset == Vector2(-2, 0))
	Input.action_release(ControllerHandler.left_action)
	await tick(60)
	assert(player.state_machine.current_state is MarioIdleState)
	assert(is_zero_approx(player.body.velocity.x))
	assert(player.sprite.offset == Vector2.ZERO)
	assert(player.sprite.frame == 0 and not player.animation_player.is_playing())
	Input.action_press(ControllerHandler.right_action)
	Input.action_press(ControllerHandler.secondary_action)
	await tick(65)
	assert(ControllerHandler.input_secondary)
	assert(is_equal_approx(player.motion_values.max_speed, player.run_action.max_speed))
	assert(is_equal_approx(player.body.velocity.x, player.run_action.max_speed))
	Input.action_release(ControllerHandler.secondary_action)
	await tick(2)
	assert(is_equal_approx(player.motion_values.max_speed, player.motion_values.base_max_speed))
	assert(player.body.velocity.x > player.motion_values.base_max_speed)
	await tick(40)
	assert(is_equal_approx(player.body.velocity.x, player.motion_values.base_max_speed))
	Input.action_release(ControllerHandler.right_action)
	await tick(60)
	Input.action_press(ControllerHandler.right_action)
	await tick(15)
	ControllerHandler.enabled = false
	await tick(60)
	var stopped_position := player.body.global_position
	await tick(5)
	assert(player.body.global_position.is_equal_approx(stopped_position))
	assert(player.state_machine.current_state is MarioIdleState)
	Input.action_release(ControllerHandler.right_action)
	ControllerHandler.enabled = true
	# The reusable action changes X only and is independent of frame rate.
	var action := HorizontalMovementComponent.new()
	var values := MotionValues.new()
	var slow := CharacterBody2D.new()
	var fast := CharacterBody2D.new()
	slow.velocity.y = 42.0
	fast.velocity.y = 42.0
	for index in range(6):
		action.apply(slow, values, 1.0, 1.0 / 30.0)
	for index in range(12):
		action.apply(fast, values, 1.0, 1.0 / 60.0)
	assert(slow.velocity.is_equal_approx(fast.velocity))
	assert(slow.velocity.y == 42.0)
	var other_values := MotionValues.new()
	values.body = slow
	values.velocity = Vector2(5, 7)
	assert(slow.velocity == Vector2(5, 7))
	values.set_modifier(&"level", {&"max_speed": 60.0}, 200)
	player.run_action.apply(values, true)
	assert(values.max_speed == 60.0)
	assert(values.acceleration == player.run_action.acceleration)
	values.set_modifier(&"state", {&"max_speed": 30.0}, 300)
	assert(values.max_speed == 30.0)
	values.remove_modifier(&"state")
	assert(values.max_speed == 60.0)
	player.run_action.apply(values, false)
	assert(values.max_speed == 60.0)
	assert(other_values.max_speed == other_values.base_max_speed)
	values.remove_modifier(&"level")
	assert(values.max_speed == values.base_max_speed)
	var bindings := InputMap.action_get_events(ControllerHandler.secondary_action)
	assert(bindings.size() == 2)
	assert(bindings[0] is InputEventKey and bindings[0].physical_keycode == KEY_SHIFT)
	assert(bindings[0].location == KEY_LOCATION_LEFT)
	assert(bindings[1] is InputEventJoypadButton and bindings[1].button_index == JOY_BUTTON_X)
	values.free()
	other_values.free()
	slow.free()
	fast.free()
	action.free()
	game.free()
	print("PASS: walk/run, static Idle, bindings, reversal/braking, control gates, shared motion modifiers, body velocity proxy, isolation, and timestep independence.")
	get_tree().quit()

