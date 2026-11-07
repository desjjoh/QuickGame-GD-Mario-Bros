extends Node

signal physics_step_finished


func _physics_process(_delta: float) -> void:
	physics_step_finished.emit()


func ticks(count: int) -> void:
	for frame in range(count):
		await physics_step_finished


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 200
	var game = load("res://tests/fixtures/silent_game.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Keep pipe-emergence coverage independent of the stage's current return route.
	var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	fixture.get_node("Areas/MainArea/Layouts/EntityLayout").set_cell(
		Vector2i(4, 11), 3, Vector2i.ZERO
	)
	var arrival := TransportPlacement.new()
	arrival.cell = Vector2i(4, 11)
	arrival.target_id = &"stage_return"
	arrival.entrance_enabled = false
	fixture.get_node("Areas/MainArea").transport_points.append(arrival)
	var lower_fixture := fixture.get_node("Areas/LowerArea") as BaseLevelArea
	var route := lower_fixture.transport_points[0].duplicate() as TransportPlacement
	route.destination = TransportDestination.create(&"main", &"stage_return")
	lower_fixture.transport_points = [route]
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area, true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	game.initial_level = packed
	add_child(game)
	var level: BaseLevel = GameHandler.current_level
	assert(level.request_area_transfer(&"lower"))
	await get_tree().process_frame
	await ticks(5)
	var lower: BaseLevelArea = level.active_area
	var pipe: PipeEntrance = null
	for entity in lower.get_node("WorldObjects").get_children():
		if entity is PipeEntrance and entity.sideways:
			pipe = entity
	assert(pipe != null)
	assert(pipe.sideways)
	for theme_path in [
		"res://assets/themes/overworld.tres", "res://assets/themes/underground.tres"
	]:
		var theme = load(theme_path) as AreaTheme
		var source := theme.terrain.get_source(1) as TileSetAtlasSource
		for coords in [Vector2i(5, 2), Vector2i(5, 3), Vector2i(6, 2), Vector2i(6, 3)]:
			assert(source.get_tile_data(coords, 0).get_collision_polygons_count(0) == 1)
		assert(
			(
				theme.entity_markers.get_source(4).get_tile_size_in_atlas(Vector2i.ZERO)
				== Vector2i(2, 2)
			)
		)
	var player: BasePlayer = level.player
	player.body.global_position = pipe.to_global(Vector2(-14, 32))
	player.body.velocity = Vector2.ZERO
	player.body.reset_physics_interpolation()
	await ticks(5)
	assert(player.body.is_on_floor())
	var original_mask = player.body.collision_mask
	var sound_count := [0]
	player.body.child_entered_tree.connect(
		func(child: Node):
			if child is AudioStreamPlayer:
				sound_count[0] += 1
	)
	Input.action_press(ControllerHandler.right_action)
	var entered := false
	for frame in range(60):
		await ticks(1)
		if player.state_machine.current_state == player.pipe_enter_state:
			entered = true
			break
	assert(entered, "Walking into the grounded left-facing mouth must trigger entry.")
	await preload("res://tests/fixtures/pause_check.gd").check(level)
	assert(player.body.collision_mask == 0)
	var start = player.body.global_position
	assert(player.animation_player.current_animation == &"walk")
	assert(not player.sprite.flip_h)
	var first_texture = player.sprite.texture
	await ticks(10)
	assert(player.sprite.texture != first_texture, "Side entry must cycle the walking sprites.")
	assert(player.body.global_position.x > start.x)
	assert(is_equal_approx(player.body.global_position.y, start.y))
	Input.action_release(ControllerHandler.right_action)
	await ticks(20)
	assert(
		player.body.global_position == start + Vector2(14, 0),
		"Side entry stops with the sprite left edge on the next 16px boundary."
	)
	assert(not player.animation_player.is_playing())
	assert(level.active_area == lower, "The concealed wait must complete before transfer.")
	var stopped = player.body.global_position
	await ticks(10)
	assert(player.body.global_position == stopped)
	var early_idle := [0]
	player.state_machine.state_changed.connect(
		func(_old: BaseState, next: BaseState):
			if next == player.state_machine.initial_state:
				early_idle[0] += 1
	)
	await ticks(39)
	assert(
		level.active_area == lower,
		"At side-entry tick 79 the 52-tick concealed wait is not finished."
	)
	await ticks(1)  # 28 moving ticks + 52 concealed ticks.
	await get_tree().process_frame  # Complete the deferred area handoff.
	assert(level.active_area.area_id == &"main")
	assert(not lower.runtime_loaded)
	assert(player.state_machine.current_state == player.pipe_enter_state)
	assert(player.body.collision_mask == 0)
	assert(level.players.get_index() < level.get_node("Areas").get_index())
	assert(
		early_idle[0] == 0,
		"Handoff must not briefly activate normal controls between entry and exit."
	)
	assert(level.active_target_id == &"stage_return")
	assert(level.active_endpoint == null, "Pipe arrival must not require a standalone marker.")
	var target := level.active_area.find_transport_entity(&"stage_return")
	assert(target != null and not target.entrance_enabled)
	var end_position := target.exit_position()
	assert(
		end_position.x < 128.0, "The secret exit returns to the start, not the original entrance."
	)
	assert(target.exit_distance == 96.0)
	assert(player.body.global_position == end_position + Vector2(0, 96))
	assert(not player.sprite.visible and not player.sprite.flip_h)
	var hidden_y = player.body.global_position.y
	await preload("res://tests/fixtures/pause_check.gd").check(level)
	await ticks(12)
	assert(is_equal_approx(player.body.global_position.y, hidden_y - 12.0))
	assert(not player.sprite.visible)
	await ticks(83)
	assert(player.state_machine.current_state == player.pipe_enter_state)
	assert(player.body.collision_mask == 0)
	assert(not player.pipe_enter_state.controls_enabled)
	assert(player.body.global_position == end_position + Vector2(0, 1))
	assert(player.sprite.visible)
	assert(sound_count[0] == 1, "Play the pipe sound on entry only; emergence remains silent.")
	Input.action_press(ControllerHandler.left_action)
	Input.action_press(ControllerHandler.primary_action)
	await ticks(1)
	await get_tree().process_frame  # Complete the deferred control handoff.
	assert(
		player.body.global_position == end_position,
		"Final emergence tick cannot execute normal movement/jump."
	)
	assert(player.state_machine.current_state != player.pipe_enter_state)
	assert(player.body.collision_mask == original_mask)
	assert(player.sprite.visible)
	assert(level.players.get_index() > level.get_node("Areas").get_index())
	await ticks(2)
	assert(
		player.body.global_position.x < end_position.x,
		"Held direction works on normal physics after emergence without requiring release."
	)
	assert(
		player.body.velocity.y >= 0.0,
		"A jump pressed during the final locked tick is not buffered."
	)
	Input.action_release(ControllerHandler.left_action)
	Input.action_release(ControllerHandler.primary_action)
	await ticks(1)
	assert(level.can_enter_pipe())
	assert(GameHandler.get_session_value(&"current_area_id") == &"main")
	game.free()
	await ticks(6)
	await get_tree().process_frame
	print(
		"PASS: sideways pipe activates from walking contact, streams areas, emerges upward and restores collision/control/draw order."
	)
	get_tree().quit()
