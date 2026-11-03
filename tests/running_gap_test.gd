extends Node


func tick() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame


func _ready() -> void:
	for direction in [-1.0, 1.0]:
		for phase in [0.0, 0.5, 1.0, 1.5, 2.0]:
			var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
			add_child(game)
			preload("res://tests/test_floor.gd").extend_floor(game)
			var level := GameHandler.current_level
			level.keep_player_on_screen = false
			(get_viewport().get_camera_2d() as LevelCamera).follow_enabled = false
			var ground := level.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
			for y in [13, 14]:
				ground.erase_cell(Vector2i(6, y))
			var player := level.player
			player.body.global_position.x = (84.0 if direction > 0 else 124.0) + direction * phase
			for frame in range(5):
				await tick()
			var action: StringName = ControllerHandler.right_action if direction > 0 else ControllerHandler.left_action
			Input.action_press(action)
			Input.action_press(ControllerHandler.secondary_action)
			player.body.velocity.x = direction * 150.0
			player.face_direction(direction)
			player.state_machine.change_state(player.state_machine.get_state(&"Move"))
			for frame in range(25):
				await tick()
				assert(player.body.global_position.y < 212.0, "Run must recover shallow one-tile gaps.")
				assert(player.state_machine.current_state is MarioMoveState,
					"Passive gap crossing must remain in Move, with no Jump pose flash.")
				assert(player.animation_player.current_animation == "walk")
				assert(absf(player.body.velocity.x) > 140.0, "Gap contact must preserve run momentum: direction=%s phase=%s frame=%s pos=%s velocity=%s" % [direction, phase, frame, player.body.global_position, player.body.velocity])
			assert(player.body.is_on_floor())
			Input.action_release(action)
			Input.action_release(ControllerHandler.secondary_action)
			game.free()
	var wide_game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
	add_child(wide_game)
	preload("res://tests/test_floor.gd").extend_floor(wide_game)
	var wide_level := GameHandler.current_level
	wide_level.keep_player_on_screen = false
	var wide_ground := wide_level.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
	for x in [6, 7]:
		for y in [13, 14]:
			wide_ground.erase_cell(Vector2i(x, y))
	var wide_player := wide_level.player
	wide_player.body.global_position.x = 84.0
	for frame in range(5):
		await tick()
	Input.action_press(ControllerHandler.right_action)
	Input.action_press(ControllerHandler.secondary_action)
	wide_player.body.velocity.x = 150.0
	wide_player.state_machine.change_state(wide_player.state_machine.get_state(&"Move"))
	for frame in range(25):
		await tick()
	assert(wide_player.body.global_position.y > 220.0, "A two-tile gap must still cause a fall.")
	assert(wide_player.state_machine.current_state is MarioMoveState)
	assert(not wide_player.jump_action.active)
	Input.action_release(ControllerHandler.right_action)
	Input.action_release(ControllerHandler.secondary_action)
	wide_game.free()
	print("PASS: one-tile gap runs in both directions at five subpixel phases; wider gaps still cause falling.")
	get_tree().quit()
