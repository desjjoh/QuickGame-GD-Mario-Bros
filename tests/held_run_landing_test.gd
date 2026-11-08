extends Node


func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func send_button(keyboard: bool, run: bool, pressed: bool) -> void:
	var event: InputEvent
	if keyboard:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_SHIFT if run else KEY_SPACE
		key.location = KEY_LOCATION_LEFT if run else KEY_LOCATION_UNSPECIFIED
		key.pressed = pressed
		event = key
	else:
		var button := InputEventJoypadButton.new()
		button.device = 2
		button.button_index = JOY_BUTTON_X if run else JOY_BUTTON_A
		button.pressed = pressed
		event = button
	Input.parse_input_event(event)


func _ready() -> void:
	for keyboard in [true, false]:
		for direction in [-1.0, 1.0]:
			var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
			add_child(game)
			preload("res://tests/test_floor.gd").extend_floor(game)
			var player := GameHandler.current_player
			player.jump_action.sound_effect = null
			var forward := (
				ControllerHandler.left_action if direction < 0 else ControllerHandler.right_action
			)
			Input.action_press(forward)
			send_button(keyboard, true, true)
			await ticks(65)
			assert(is_equal_approx(absf(player.body.velocity.x), 150.0))
			for jump in range(4):
				send_button(keyboard, false, true)
				await ticks(2)
				assert(player.state_machine.current_state is MarioJumpState)
				send_button(keyboard, false, false)
				var landed := false
				for frame in range(90):
					await ticks(1)
					assert(Input.is_action_pressed(ControllerHandler.secondary_action))
					assert(ControllerHandler.input_secondary and player.can_read_controller_input())
					if player.body.is_on_floor():
						landed = true
						break
				assert(landed)
				await ticks(3)
				assert(player.state_machine.current_state is MarioMoveState)
				assert(not player.motion_values._modifiers.has(&"air"))
				assert(player.motion_values.max_speed == 150.0)
				assert(is_equal_approx(absf(player.body.velocity.x), 150.0))
			send_button(keyboard, true, false)
			Input.action_release(forward)
			game.free()
			await ticks(2)
	print(
		"PASS: continuously held keyboard/controller Run survives 16 jump/landing cycles in both directions, with no stale air cap or re-press."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
