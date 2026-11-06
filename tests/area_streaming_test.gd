extends Node


func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func floor_hit(at: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(at - Vector2(0, 2), at + Vector2(0, 2), 1)
	return not get_viewport().world_2d.direct_space_state.intersect_ray(query).is_empty()


func _ready() -> void:
	GameHandler.clear_session()
	var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
	var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	for area in fixture.get_node("Areas").get_children():
		area.get_node("Layouts/EntityLayout").clear()
		var floor := area.get_node("Layouts/GroundLayout") as TileMapLayer
		floor.clear()
		for x in range(16):
			floor.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
		fixture.set_editable_instance(area, true)
	var markers := fixture.get_node("Areas/MainArea/Layouts/EntityLayout") as TileMapLayer
	markers.set_cell(Vector2i(4, 9), 1, Vector2i.ZERO)
	markers.set_cell(Vector2i(6, 11), 3, Vector2i.ZERO)
	markers.set_cell(Vector2i(3, 8), 0, Vector2i.ZERO)
	fixture.get_node("Areas/LowerArea/Layouts/EntityLayout").set_cell(
		Vector2i(4, 9), 0, Vector2i.ZERO
	)
	fixture.get_node("Players/PlayerSpawn").position = Vector2(48, 208)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	assert(ResourceSaver.save(packed, "res://.godot/validation/streaming-persistence.tscn") == OK)
	fixture.free()
	game.initial_level = load("res://.godot/validation/streaming-persistence.tscn")
	add_child(game)
	await ticks(5)
	var level := GameHandler.current_level
	var main := level.active_area
	var lower := level.get_node("Areas/LowerArea") as BaseLevelArea
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	assert(main.runtime_loaded and not lower.runtime_loaded)
	assert(
		(
			not lower.has_node("Layouts")
			and not lower.has_node("WorldObjects")
			and not lower.has_node("Camera2D")
		)
	)
	assert(lower.resolve_endpoint(&"arrival") != null)
	assert(floor_hit(Vector2(8, 208)))
	var lower_floor := lower.to_global(Vector2(8, 208))
	assert(not floor_hit(lower_floor), "Unloaded terrain must have no physics collision.")
	var question := main.get_node("WorldObjects/question_block_4_9") as BaseBlock
	var old_question: WeakRef = weakref(question)
	var old_pipe: WeakRef = weakref(main.get_node("WorldObjects/pipe_entrance_6_11"))
	assert(question.receive_hit(EntityHit.new(level.player, &"bonk", Vector2.UP)))
	assert(question.state_machine.current_state.name == &"Bouncing")
	var removed := main.get_node("WorldObjects/brick_3_8") as BaseBlock
	removed.shutdown()
	removed.free()
	main.get_node("Layouts/GroundLayout").erase_cell(Vector2i(10, 13))
	GameHandler.set_session_value(&"coins", 13)
	assert(level.request_area_transfer(&"lower"))
	await ticks(2)
	assert(not main.runtime_loaded and lower.runtime_loaded)
	assert(
		(
			not main.has_node("Layouts")
			and not main.has_node("WorldObjects")
			and not main.has_node("Camera2D")
		)
	)
	assert(old_question.get_ref() == null and old_pipe.get_ref() == null)
	assert(not floor_hit(Vector2(8, 208)) and floor_hit(lower_floor))
	assert(not level.has_node("ForegroundObjects"))
	var state := GameHandler.get_area_progress(level._progress_key, &"main")
	assert(state["entities"]["question_block_4_9"]["state"]["state"] == &"Inactive")
	assert(not state["entities"].has("brick_3_8"))
	var old_lower: WeakRef = weakref(lower.get_node("WorldObjects/brick_4_9"))
	for visit in range(3):
		assert(level.request_area_transfer(&"main", &"player_spawn"))
		await ticks(2)
		assert(main.runtime_loaded and not lower.runtime_loaded)
		assert(old_lower.get_ref() == null)
		question = main.get_node("WorldObjects/question_block_4_9") as BaseBlock
		assert(question.state_machine.current_state.name == &"Inactive")
		assert(question.sprite.texture.resource_path.ends_with("question-block-4.tres"))
		assert(main.has_node("WorldObjects/brick_3_8"))
		assert(main.get_node("Layouts/GroundLayout").get_cell_source_id(Vector2i(10, 13)) == -1)
		assert(main.get_node("WorldObjects").get_child_count() == 3)
		assert(main.get_node("WorldObjects/pipe_entrance_6_11/Visuals").get_child_count() == 4)
		assert(GameHandler.get_session_value(&"coins") == 13)
		assert(level.request_area_transfer(&"lower"))
		await ticks(2)
		assert(not main.runtime_loaded and lower.runtime_loaded)
		assert(not level.has_node("ForegroundObjects"))
		old_lower = weakref(lower.get_node("WorldObjects/brick_4_9"))
	var progress_key := level._progress_key
	game.free()
	await ticks(2)
	assert(not GameHandler.get_area_progress(progress_key, &"main").is_empty())
	# The handler also owns progress across replacing the level instance.
	game = load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
	game.initial_level = load("res://.godot/validation/streaming-persistence.tscn")
	add_child(game)
	level = GameHandler.current_level
	question = level.world_objects.get_node("question_block_4_9") as BaseBlock
	assert(question.state_machine.current_state.name == &"Inactive")
	assert(level.world_objects.has_node("brick_3_8"))
	game.free()
	await ticks(2)
	GameHandler.clear_session()
	assert(GameHandler.get_area_progress(progress_key, &"main").is_empty())
	print(
		"PASS: only occupied runtime loaded, inactive collisions/entities/camera freed, used question blocks and tile edits persist, bricks reset through repeated visits, and pipe visuals clean up."
	)
	get_tree().quit()
