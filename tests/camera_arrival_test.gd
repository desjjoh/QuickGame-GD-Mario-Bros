extends Node


func ticks(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	game.start_with_title = false
	game.transitions_enabled = false
	add_child(game)
	var level := GameHandler.current_level
	await ticks(3)
	assert(level.request_area_transfer(&"lower", &"arrival"))
	await ticks(5)
	assert(level.active_area.area_id == &"lower")
	assert(level.transport(level.player, TransportDestination.create(&"main", &"secret_exit")))
	for i in range(180):
		await ticks(1)
		if (
			level.active_area.area_id == &"main"
			and not level.transition_in_progress
			and not level.area_transport.has_active_state()
		):
			break
	var camera := level.active_area.get_node("Camera2D") as LevelCamera
	var left := camera.global_position.x - 128
	print(
		"RETURN body=",
		level.player.body.global_position,
		" camera_left=",
		left,
		" body_screen_x=",
		level.player.body.global_position.x - left,
		" sprite_left_screen=",
		level.player.body.global_position.x - 8 - left
	)
	assert(is_equal_approx(level.player.body.global_position.x - left, 64.0))
	assert(is_equal_approx(level.player.body.global_position.x - 8 - left, 56.0))
	var before_camera := camera.global_position.x
	await ticks(4)
	assert(is_equal_approx(camera.global_position.x, before_camera))
	level.player.camera_correction_x += 4
	level.player.body.global_position.x += 4
	camera.follow_target(level.player.body)
	assert(is_equal_approx(camera.global_position.x, before_camera))
	camera.follow_target(level.player.body)
	assert(is_equal_approx(camera.global_position.x, before_camera))
	game.free()
	await ticks(2)
	print("camera_arrival_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
