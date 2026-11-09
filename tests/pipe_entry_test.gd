extends Node


func _ready() -> void:
	var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
	var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	if "--super" in OS.get_cmdline_user_args():
		fixture.player_start_configuration = preload("res://assets/player/forms/super.tres")
	fixture.get_node("Areas/MainArea/Layouts/EntityLayout").clear()
	fixture.get_node("Areas/MainArea/Layouts/EntityLayout").set_cell(
		Vector2i(6, 11), 3, Vector2i.ZERO
	)
	fixture.get_node("Players/PlayerSpawn").position = Vector2(112, 176)
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area, true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	game.stages.assign([packed])
	add_child(game)
	var level := GameHandler.current_level
	var player := level.player
	var pipe := level.world_objects.get_node("pipe_entrance_6_11") as PipeEntrance
	for frame in range(6):
		await get_tree().physics_frame
		await get_tree().process_frame
	assert(player.body.is_on_floor())
	player.set_physics_process(false)
	level.set_physics_process(false)
	pipe.set_physics_process(false)
	player.body.global_position.x = 110
	player.face_direction(-1.0)
	var origin := player.body.global_position
	var layer := player.body.collision_layer
	var mask := player.body.collision_mask
	var camera := get_viewport().get_camera_2d()
	var camera_origin := camera.global_position
	var transient := AreaEndpoint.new()
	transient.endpoint_id = &"temporary"
	level.get_node("Areas/LowerArea/Endpoints").add_child(transient)
	pipe.destination_endpoint_id = &"temporary"
	var sounds: Array[AudioStreamPlayer] = []
	player.body.child_entered_tree.connect(
		func(child: Node):
			if child is AudioStreamPlayer:
				sounds.append(child)
	)
	ControllerHandler.input_down = 1
	ControllerHandler.input_up = 1
	pipe._physics_process(1.0 / 60.0)
	assert(player.state_machine.current_state == player.pipe_enter_state)
	ControllerHandler.input_up = 0
	assert(level.players.get_index() < level.get_node("Areas").get_index())
	# Entry aligns feet to the mouth; floor contact may retain a safe-margin offset.
	var entry_origin := player.body.global_position
	assert(is_equal_approx(entry_origin.y, pipe.entry_position().y))
	assert(sounds.size() == 1 and sounds[0].playing)
	ControllerHandler.input_primary_just_pressed = true
	ControllerHandler.input_primary = true
	ControllerHandler.input_right = 1
	ControllerHandler.input_secondary = true
	for frame in range(12):
		player.state_machine.process_physics(1.0 / 60.0)
		level._physics_process(1.0 / 60.0)
	assert(is_equal_approx(player.body.global_position.y - entry_origin.y, 12.0))
	assert(player.body.global_position.x == origin.x)
	assert(player.sprite.flip_h, "Vertical entry must preserve left facing.")
	assert(player.body.velocity == Vector2.ZERO)
	assert(camera.global_position == camera_origin)
	assert(player.state_machine.current_state == player.pipe_enter_state)
	assert(sounds.size() == 1)
	transient.free()
	level._physics_process(1.0 / 60.0)
	assert(player.body.global_position == origin)
	assert(level.players.get_index() > level.get_node("Areas").get_index())
	assert(player.body.collision_layer == layer and player.body.collision_mask == mask)
	assert(player.sprite.visible)
	assert(player.state_machine.current_state == player.state_machine.initial_state)
	assert(not sounds[0].playing)
	ControllerHandler.input_down = 0
	ControllerHandler.input_primary_just_pressed = false
	ControllerHandler.input_primary = false
	ControllerHandler.input_right = 0
	ControllerHandler.input_secondary = false
	level._physics_process(1.0 / 60.0)
	assert(level.can_transport())
	pipe.destination_endpoint_id = &"arrival"
	player.body.global_position.x = 114
	player.face_direction(1.0)
	origin = player.body.global_position
	assert(level.transport(level.player, pipe.get_destination(), pipe))
	assert(player.body.global_position.x == 114)
	assert(not player.sprite.flip_h, "Vertical entry must preserve right facing too.")
	player.state_machine.process_physics(0.1)
	assert(player.body.global_position.x == 114 and not player.sprite.flip_h)
	level.shutdown()
	assert(player.is_shutdown and player.state_machine.current_state == null)
	assert(player.body.collision_layer == layer and player.body.collision_mask == mask)
	assert(player.sprite.visible and player.body.global_position == origin)
	assert(not level.request_area_transfer(&"lower"))
	game.free()
	for frame in range(2):
		await get_tree().process_frame
	print(
		"PASS: PipeEnter ignores controls, moves at reference speed, freezes camera, plays once, cancels invalid targets and restores state/collision on shutdown."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
