extends Node


func make_game() -> Node:
	# Scrolling needs a wide fixture, independent of the playable test-stage size.
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	var level := load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	var camera := level.get_node("Cameras/Camera2D") as LevelCamera
	camera.position = Vector2(0, 120)
	camera.world_left = -128.0
	camera.world_right = 768.0
	level.find_child("PlayerSpawn", true, false).position = Vector2(-88, 208)
	var ground := level.get_node("Layouts/GroundLayout") as TileMapLayer
	ground.clear()
	level.get_node("Layouts/EntityLayout").clear()
	for x in range(-8, 48):
		for y in [13, 14]:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var packed := PackedScene.new()
	assert(packed.pack(level) == OK)
	level.free()
	game.initial_level = packed
	return game


func _ready() -> void:
	var game := make_game()
	add_child(game)
	var level := GameHandler.current_level
	var camera := get_viewport().get_camera_2d() as LevelCamera
	var body := level.player.body
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	body.global_position.x = -42.0
	camera.reset_target(body)
	body.global_position.x = -41.0
	camera.follow_target(body)
	assert(camera.global_position.x == 0.0, "No scroll before 80-pixel threshold.")
	body.global_position.x = -40.0
	camera.follow_target(body)
	assert(camera.global_position.x == 0.5)
	body.global_position.x = -37.0
	camera.follow_target(body)
	assert(camera.global_position.x == 2.0, "Early scrolling tracks at a steady half speed.")
	body.global_position.x = 10.0
	camera.reset_target(body)
	body.global_position.x = 13.0
	camera.follow_target(body)
	assert(camera.global_position.x == 5.0, "Full scroll after the 112-pixel threshold.")
	body.global_position.x = 0.0
	camera.follow_target(body)
	assert(camera.global_position.x == 5.0, "Camera must not scroll backward.")
	body.global_position.x = 100.0
	camera.reset_target(body)
	for frame in range(20):
		var before := camera.global_position.x
		body.global_position.x += 2.5
		camera.follow_target(body)
		assert(is_equal_approx(camera.global_position.x - before, 2.5),
			"Steady running must not alternate between 2- and 3-pixel camera steps.")
	body.global_position.x = 2000.0
	camera.follow_target(body)
	assert(camera.global_position == Vector2(640, 120), "Stop at right world boundary; Y stays fixed.")
	game.free()
	game = make_game()
	add_child(game)
	level = GameHandler.current_level
	camera = get_viewport().get_camera_2d() as LevelCamera
	Input.action_press(ControllerHandler.right_action)
	Input.action_press(ControllerHandler.secondary_action)
	var previous_x := camera.global_position.x
	for frame in range(420):
		await get_tree().physics_frame
		await get_tree().process_frame
		assert(camera.global_position.x >= previous_x)
		assert(camera.global_position.y == 120.0)
		previous_x = camera.global_position.x
	Input.action_release(ControllerHandler.right_action)
	Input.action_release(ControllerHandler.secondary_action)
	assert(camera.global_position.x == 640.0)
	assert(level.player.body.is_on_floor())
	assert(level.player.body.global_position.x <= 761.0)
	game.free()
	print("PASS: reference scroll thresholds, early/full-speed steps, no backward/vertical scroll, world limits, and live run to level end.")
	get_tree().quit()
