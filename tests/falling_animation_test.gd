extends Node


func tick() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame


func _ready() -> void:
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	add_child(game)
	var player := GameHandler.current_player as Mario
	for frame in range(5):
		await tick()
	player.body.global_position = Vector2(40, 160)
	player.body.velocity = Vector2(60, 60)
	# Refresh floor flags after moving the fixture into open air.
	player.body.move_and_slide()
	Input.action_press(ControllerHandler.right_action)
	player.state_machine.change_state(player.state_machine.get_state(&"Move"))
	player.animation_player.seek(0.15, true)
	var frame_texture := player.sprite.texture
	var phase := player.animation_player.current_animation_position
	for frame in range(5):
		await tick()
		assert(not player.body.is_on_floor())
		assert(player.state_machine.current_state is MarioMoveState)
		assert(player.animation_player.speed_scale == 0.0)
		assert(player.animation_player.current_animation_position == phase)
		assert(player.sprite.texture == frame_texture)
	for frame in range(30):
		await tick()
	assert(player.body.is_on_floor())
	assert(player.animation_player.speed_scale > 0.0)
	assert(player.animation_player.current_animation_position != phase)
	Input.action_release(ControllerHandler.right_action)
	game.free()
	print("PASS: passive falling freezes the current walk pose and phase; landing resumes playback.")
	get_tree().quit()
