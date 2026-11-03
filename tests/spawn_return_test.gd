extends Node

func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func _ready() -> void:
	var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
	add_child(game)
	var level: BaseLevel = GameHandler.current_level
	var main := level.active_area
	assert(main.find_transport_entity(&"stage_return") == null)
	assert(level.transport(level.player, TransportDestination.create(&"lower", &"arrival")))
	await ticks(5)
	var lower := level.active_area
	assert(not main.runtime_loaded)
	# The target must follow PlayerSpawn itself, even while its area is unloaded.
	level.player_spawn.position.x += 16
	var expected := level.player_spawn.global_position
	var pipe := lower.find_transport_entity(&"secret_return") as PipeEntrance
	assert(pipe.get_destination().target_id == &"player_spawn")
	var player := level.player
	player.body.global_position = pipe.to_global(Vector2(-14,32))
	player.body.velocity = Vector2.ZERO
	player.body.reset_physics_interpolation()
	await ticks(5)
	var mask := player.body.collision_mask
	Input.action_press(ControllerHandler.right_action)
	for frame in range(150):
		await ticks(1)
		if level.active_area == main:
			break
	Input.action_release(ControllerHandler.right_action)
	assert(level.active_area == main and not lower.runtime_loaded)
	assert(level.active_target_id == &"player_spawn")
	assert(player.body.global_position == expected)
	assert(player.sprite.visible and player.body.collision_mask == mask)
	assert(player.state_machine.current_state == player.state_machine.initial_state)
	assert(level.players.get_index() > level.get_node("Areas").get_index())
	assert(main.find_transport_entity(&"stage_return") == null)
	assert(get_viewport().get_camera_2d() == main.get_node("Camera2D"))
	assert(GameHandler.get_session_value(&"current_target_id") == &"player_spawn")
	game.free()
	await ticks(6)
	print("PASS: secret pipe returns to the actual moved PlayerSpawn, restoring camera/control without an exit pipe or emergence.")
	get_tree().quit()
