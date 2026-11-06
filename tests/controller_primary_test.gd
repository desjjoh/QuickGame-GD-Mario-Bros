extends Node


func _ready() -> void:
	call_deferred("run_checks")


func tick(count: int) -> void:
	for index in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame


func button(device: int, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	return event


func run_checks() -> void:
	assert(ControllerHandler.primary_action == &"primary")
	for code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		var key := InputEventKey.new()
		key.physical_keycode = code
		key.pressed = true
		assert(key.is_action_pressed(ControllerHandler.primary_action))
	for device in [0, 1, 2]:
		var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
		get_tree().root.add_child(game)
		var mario := GameHandler.current_player
		await tick(5)
		assert(mario.body.is_on_floor())
		var jump_sound := SoundHandler.get_sound(mario.jump_action.sound_cue) as AudioStreamWAV
		assert(
			jump_sound.loop_mode == AudioStreamWAV.LOOP_DISABLED,
			"One-shot jump audio must not inherit the WAV's invalid embedded loop."
		)
		var playback := jump_sound.instantiate_playback()
		playback.start(0.0)
		var decoded := playback.mix_audio(1.0, 30000)
		var peak := 0.0
		for sample in decoded:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		playback.stop()
		assert(
			peak > 0.05, "Jump audio must decode actual audible samples, not just create a node."
		)
		playback = null
		jump_sound = null
		var jumps: Array[int] = []
		var sounds: Array[AudioStream] = []
		mario.body.child_entered_tree.connect(
			func(child: Node):
				if child is AudioStreamPlayer:
					sounds.append(child.stream)
		)
		mario.jump_action.jumped.connect(func(): jumps.append(1))
		var event := button(device, true)
		assert(event.is_action_pressed(ControllerHandler.primary_action))
		Input.parse_input_event(event)
		await tick(3)
		assert(ControllerHandler.input_primary)
		assert(mario.state_machine.current_state is MarioJumpState)
		assert(mario.body.velocity.y < 0.0)
		assert(jumps.size() == 1)
		assert(sounds.size() == 1)
		assert(sounds[0] == SoundHandler.get_sound(&"jump_small"))
		assert(not mario.jump_action.begin(mario.motion_values))
		assert(jumps.size() == 1, "Rejected midair jumps must not emit another jump sound.")
		Input.parse_input_event(button(device, false))
		await tick(2)
		assert(not ControllerHandler.input_primary)
		# Let the real one-shot finish and its deferred deletion complete.
		await tick(40)
		game.free()
		sounds.clear()
		await tick(2)
	print(
		"PASS: preserved keyboard bindings and Xbox A raw-event jumps/releases on device IDs 0, 1, and 2."
	)
	get_tree().quit()
