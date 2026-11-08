extends Node


func _ready() -> void:
	var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
	# Keep the containment fixture independent of the user's room painting.
	var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	fixture.get_node("Areas/LowerArea").position = Vector2(0, 512)
	fixture.get_node("Areas/LowerArea/Camera2D").position = Vector2(128, 120)
	fixture.get_node("Areas/LowerArea/Arrival").position = Vector2(48, 208)
	var floor := fixture.get_node("Areas/LowerArea/Layouts/GroundLayout") as TileMapLayer
	floor.clear()
	fixture.get_node("Areas/LowerArea/Layouts/EntityLayout").clear()
	for x in range(16):
		for y in [0, 13, 14]:
			floor.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	for y in range(1, 13):
		for x in [0, 15]:
			floor.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var packed := PackedScene.new()
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area, true)
	assert(packed.pack(fixture) == OK)
	fixture.free()
	game.stages.assign([packed])
	add_child(game)
	var level := GameHandler.current_level
	var room := level.get_node("Areas/LowerArea") as Node2D
	assert(not (room as BaseLevelArea).runtime_loaded)
	assert(not room.has_node("Camera2D"))
	assert(get_viewport().get_camera_2d() == level.get_node("Areas/MainArea/Camera2D"))
	level.player.face_direction(-1.0)
	assert(level.player.sprite.flip_h)
	level.player.jump_action.falling_gravity = 2025.0
	assert(not level.request_area_transfer(&"missing"))
	assert(level.player.jump_action.falling_gravity == 2025.0)
	assert(level.request_area_transfer(&"lower"))
	await get_tree().process_frame
	assert(level.player.jump_action.falling_gravity == 562.5)
	assert(not level.player.sprite.flip_h, "Area arrival must reset facing right.")
	var camera := room.get_node("Camera2D") as LevelCamera
	assert(camera.enabled and not camera.follow_enabled)
	var ground := level.get_node("Areas/LowerArea/Layouts/GroundLayout") as TileMapLayer
	for x in range(16):
		assert(ground.get_cell_source_id(Vector2i(x, 0)) == 0)
		assert(ground.get_cell_source_id(Vector2i(x, 13)) == 0)
	for y in range(1, 13):
		assert(ground.get_cell_source_id(Vector2i(0, y)) == 0)
		assert(ground.get_cell_source_id(Vector2i(15, y)) == 0)
	# Continue motion trials in the newly loaded destination area.
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
			assert(
				player.body.global_position.y >= 528.0 and player.body.global_position.y <= 720.1
			)
			assert(camera.global_position == center)
		Input.action_release(direction)
	assert(player.body.is_on_floor())
	game.free()
	print(
		"PASS: enclosed lower room, inactive dedicated camera, fixed view and contained player after simulated arrival."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
