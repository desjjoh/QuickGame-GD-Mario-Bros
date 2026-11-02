extends Node


func _ready() -> void:
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	var fixture := load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	fixture.get_node("Areas/MainArea/Layouts/EntityLayout").clear()
	fixture.get_node("Areas/MainArea/Layouts/EntityLayout").set_cell(Vector2i(6,11),3,Vector2i.ZERO)
	fixture.get_node("Players/PlayerSpawn").position = Vector2(112,176)
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area,true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	game.initial_level = packed
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
	var origin := player.body.global_position
	var layer := player.body.collision_layer
	var mask := player.body.collision_mask
	var camera := get_viewport().get_camera_2d()
	var camera_origin := camera.global_position
	var transient := AreaEndpoint.new()
	transient.endpoint_id = &"temporary"
	level.get_node("Areas/LowerArea/Endpoints").add_child(transient)
	pipe.destination_endpoint_id = &"temporary"
	var sounds: Array[AudioStreamPlayer2D] = []
	player.body.child_entered_tree.connect(func(child: Node):
		if child is AudioStreamPlayer2D:
			sounds.append(child))
	assert(level.request_pipe_entry(pipe))
	assert(sounds.size() == 1 and sounds[0].playing)
	ControllerHandler.input_primary_just_pressed = true
	ControllerHandler.input_primary = true
	ControllerHandler.input_right = 1
	ControllerHandler.input_secondary = true
	for frame in range(12):
		player.state_machine.process_physics(1.0/60.0)
		level._physics_process(1.0/60.0)
	assert(is_equal_approx(player.body.global_position.y-origin.y,12.0))
	assert(player.body.global_position.x == 112)
	assert(player.body.velocity == Vector2.ZERO)
	assert(camera.global_position == camera_origin)
	assert(player.state_machine.current_state == player.pipe_enter_state)
	assert(sounds.size() == 1)
	transient.free()
	level._physics_process(1.0/60.0)
	assert(player.body.global_position == origin)
	assert(player.body.collision_layer == layer and player.body.collision_mask == mask)
	assert(player.sprite.visible)
	assert(player.state_machine.current_state == player.state_machine.initial_state)
	assert(not sounds[0].playing)
	ControllerHandler.input_down = 0
	ControllerHandler.input_primary_just_pressed = false
	ControllerHandler.input_primary = false
	ControllerHandler.input_right = 0
	ControllerHandler.input_secondary = false
	level._physics_process(1.0/60.0)
	assert(level.can_enter_pipe())
	pipe.destination_endpoint_id = &"arrival"
	assert(level.request_pipe_entry(pipe))
	player.state_machine.process_physics(0.1)
	level.shutdown()
	assert(player.is_shutdown and player.state_machine.current_state == null)
	assert(player.body.collision_layer == layer and player.body.collision_mask == mask)
	assert(player.sprite.visible and player.body.global_position == origin)
	assert(not level.request_area_transfer(&"lower"))
	game.free()
	for frame in range(2):
		await get_tree().process_frame
	print("PASS: PipeEnter ignores controls, moves at reference speed, freezes camera, plays once, cancels invalid targets and restores state/collision on shutdown.")
	get_tree().quit()
