extends Node

func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func check_duplicate_completion() -> void:
	var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
	add_child(game)
	var level: BaseLevel = GameHandler.current_level
	var player := level.player
	var endpoint := AreaEndpoint.new()
	endpoint.endpoint_id = &"animated"
	endpoint.animate_exit = true
	endpoint.position = Vector2(112,176)
	level.active_area.get_node("Endpoints").add_child(endpoint)
	var pipe := load("res://scenes/entities/pipes/pipe_entrance.tscn").instantiate() as PipeEntrance
	pipe.position = Vector2(96,176)
	level.active_area.get_node("WorldObjects").add_child(pipe)
	pipe.set_physics_process(false)
	player.body.global_position = Vector2(112,176)
	player.body.velocity = Vector2.ZERO
	await ticks(5)
	assert(player.body.is_on_floor())
	assert(level.transport(player,TransportDestination.create(&"main",&"animated"),pipe))
	player.set_physics_process(false)
	level.set_physics_process(false)
	for frame in range(48):
		player.state_machine.process_physics(1.0/60.0)
	# A second completion from the old phase must not complete the new exit phase.
	player.pipe_enter_state.travel_finished.emit()
	await get_tree().process_frame
	assert(player.state_machine.current_state == player.pipe_enter_state,
		"Duplicate entry completion must not skip the emergence animation.")
	assert(player.body.collision_mask == 0 and not player.pipe_enter_state.controls_enabled)
	assert(player.body.global_position == endpoint.global_position + Vector2(0,96))
	level.shutdown()
	assert(player.is_shutdown and player.body.collision_mask != 0 and player.sprite.visible)
	game.free()
	await ticks(6)


func _ready() -> void:
	await check_duplicate_completion()
	for trigger in [&"current_area_id", &"current_target_id"]:
		var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
		add_child(game)
		var level: BaseLevel = GameHandler.current_level
		var old_id := level.get_instance_id()
		var old_level: WeakRef = weakref(level)
		var old_player: WeakRef = weakref(level.player)
		var destination := TransportDestination.create(&"lower",&"arrival")
		if trigger == &"current_target_id":
			var endpoint := AreaEndpoint.new()
			endpoint.endpoint_id = &"animated"
			endpoint.animate_exit = true
			endpoint.position = Vector2(112,176)
			level.active_area.get_node("Endpoints").add_child(endpoint)
			destination = TransportDestination.create(&"main",&"animated")
		var replaced := [false]
		var on_session_change := func(key: StringName, value: Variant):
			if replaced[0] or key != trigger:
				return
			if (trigger == &"current_area_id" and value != &"lower") or (trigger == &"current_target_id" and value != &"animated"):
				return
			replaced[0] = true
			assert(GameHandler.load_level(load("res://tests/fixtures/silent_level.tscn")))
		GameHandler.session_value_changed.connect(on_session_change)
		assert(level.transport(level.player,destination))
		await get_tree().process_frame
		await get_tree().process_frame
		GameHandler.session_value_changed.disconnect(on_session_change)
		assert(replaced[0])
		var replacement: BaseLevel = GameHandler.current_level
		assert(replacement.get_instance_id() != old_id)
		assert(old_level.get_ref() == null or old_level.get_ref().is_shutdown)
		assert(old_player.get_ref() == null or old_player.get_ref().is_shutdown)
		assert(GameHandler.get_session_value(&"current_area_id") == replacement.active_area.area_id)
		assert(GameHandler.get_session_value(&"current_target_id") == replacement.active_target_id,
			"A cancelled transport must not overwrite the replacement level's target ID.")
		assert(GameHandler.get_session_value(&"current_endpoint_id") == replacement.active_target_id,
			"A cancelled transport must not overwrite the replacement level's compatibility target ID.")
		assert(replacement.player.state_machine.current_state == replacement.player.state_machine.initial_state)
		assert(replacement.player.sprite.visible and replacement.player.body.collision_mask != 0)
		game.free()
		for frame in range(3):
			await get_tree().process_frame
	print("PASS: level replacement during transport session notifications preserves the new level's target/session, player state and collision.")
	get_tree().quit()
