extends Node


func _ready() -> void:
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	# Keep the containment fixture independent of the user's room painting.
	var fixture := load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	fixture.get_node("Areas/LowerArea").position = Vector2(0,512)
	fixture.get_node("Areas/LowerArea/Camera2D").position = Vector2(128,120)
	fixture.get_node("Areas/LowerArea/Arrival").position = Vector2(48,208)
	var floor := fixture.get_node("Layouts/GroundLayout") as TileMapLayer
	floor.clear()
	fixture.get_node("Layouts/EntityLayout").clear()
	for x in range(16):
		for y in [32,45,46]:
			floor.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
	for y in range(33,45):
		for x in [0,15]:
			floor.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	game.initial_level = packed
	add_child(game)
	var level := GameHandler.current_level
	var room := level.get_node("Areas/LowerArea") as Node2D
	var camera := room.get_node("Camera2D") as LevelCamera
	assert(not camera.enabled and not camera.follow_enabled)
	assert(get_viewport().get_camera_2d() == level.get_node("Cameras/Camera2D"))
	var ground := level.get_node("Layouts/GroundLayout") as TileMapLayer
	for x in range(16):
		assert(ground.get_cell_source_id(Vector2i(x,32)) == 0)
		assert(ground.get_cell_source_id(Vector2i(x,45)) == 0)
	for y in range(33,45):
		assert(ground.get_cell_source_id(Vector2i(0,y)) == 0)
		assert(ground.get_cell_source_id(Vector2i(15,y)) == 0)
	# Simulate arrival only; pipe travel is intentionally not implemented yet.
	camera.enabled = true
	camera.make_current()
	var player := level.player
	player.body.global_position = room.get_node("Arrival").global_position
	player.body.velocity = Vector2.ZERO
	camera.reset_target(player.body)
	var center := camera.global_position
	for direction in ["ui_right", "ui_left"]:
		Input.action_press(direction)
		for frame in range(150):
			await get_tree().physics_frame
			await get_tree().process_frame
			assert(player.body.global_position.x >= 16.0 and player.body.global_position.x <= 240.0)
			assert(player.body.global_position.y >= 528.0 and player.body.global_position.y <= 720.1)
			assert(camera.global_position == center)
		Input.action_release(direction)
	assert(player.body.is_on_floor())
	game.free()
	print("PASS: enclosed lower room, inactive dedicated camera, fixed view and contained player after simulated arrival.")
	get_tree().quit()
