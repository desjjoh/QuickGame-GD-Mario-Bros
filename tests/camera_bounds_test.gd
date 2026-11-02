extends Node


func _ready() -> void:
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	add_child(game)
	await get_tree().process_frame
	var level := GameHandler.current_level
	var body := level.player.body
	var camera := get_viewport().get_camera_2d()
	(camera as LevelCamera).follow_enabled = false
	for zoom in [1.0, 2.0]:
		camera.zoom = Vector2.ONE * zoom
		camera.position.x = 160.0
		camera.force_update_scroll()
		var center := camera.global_position.x
		var half: float = get_viewport().get_visible_rect().size.x / zoom / 2.0
		for side in [-1.0, 1.0]:
			body.global_position = Vector2(center + side * 1000.0, 90.0)
			body.velocity = Vector2(side * 150.0, -30.0)
			level.clamp_player_to_camera()
			assert(is_equal_approx(body.global_position.x, center + side * (half - 7.0)))
			assert(body.global_position.y == 90.0)
			assert(body.velocity == Vector2(0.0, -30.0))
			for direction in [-1.0, 0.0, 1.0]:
				ControllerHandler.input_left = maxf(-direction, 0.0)
				ControllerHandler.input_right = maxf(direction, 0.0)
				for vertical_speed in [-200.0, 0.0, 200.0]:
					body.velocity = Vector2(side * 150.0, vertical_speed)
					level.clamp_player_to_camera()
					assert(body.velocity == Vector2(0.0, vertical_speed))
					body.velocity = Vector2(-side * 150.0, vertical_speed)
					level.clamp_player_to_camera()
					assert(body.velocity == Vector2(-side * 150.0, vertical_speed))
			ControllerHandler.input_left = 0.0
			ControllerHandler.input_right = 0.0
	# Reproduce airborne contact while input has already reversed inward.
	camera.zoom = Vector2.ONE
	camera.position.x = 128.0
	camera.force_update_scroll()
	var player := level.player
	body.global_position = Vector2(249.0, 160.0)
	body.velocity = Vector2(150.0, 0.0)
	player.state_machine.change_state(player.state_machine.get_state(&"Jump"))
	ControllerHandler.input_left = 1.0
	ControllerHandler.input_right = 0.0
	level.clamp_player_to_camera()
	assert(body.velocity.x == 0.0)
	Input.action_press(ControllerHandler.left_action)
	for frame in range(50):
		await get_tree().physics_frame
		await get_tree().process_frame
		assert(not player.state_machine.current_state is MarioSlideState)
	assert(body.is_on_floor())
	assert(body.global_position.x < 249.0)
	assert(player.sprite.flip_h)
	Input.action_release(ControllerHandler.left_action)
	level.keep_player_on_screen = false
	body.global_position.x = -1000.0
	level.clamp_player_to_camera()
	assert(body.global_position.x == -1000.0)
	game.free()
	print("PASS: camera bounds at both zooms, both edges, inward/outward/neutral input, horizontal speed reset, preserved vertical motion, and opt-out.")
	get_tree().quit()
