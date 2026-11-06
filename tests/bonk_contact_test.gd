extends Node

signal sweep_finished
var pending_sweep: Callable


func _physics_process(_delta: float) -> void:
	if pending_sweep.is_valid():
		var sweep := pending_sweep
		pending_sweep = Callable()
		sweep.call()
		sweep_finished.emit()


func _ready() -> void:
	# Real character sweeps at both edges, a seam, and an escapable corner.
	for trial in [
		[64.25, false, true],
		[72.0, false, true],
		[79.75, false, true],
		[79.5, true, true],
		[80.0, true, true],
		[80.5, true, true],
		[62.0, false, false],
		[63.0, false, false],
		[81.0, false, false],
		[80.5, true, false, true]
	]:
		var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
		var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
		var layout := fixture.get_node("Areas/MainArea/Layouts/EntityLayout") as TileMapLayer
		layout.clear()
		layout.set_cell(Vector2i(4, 9), 0, Vector2i.ZERO)
		if trial[1]:
			layout.set_cell(Vector2i(5, 9), 1 if trial.size() > 3 else 0, Vector2i.ZERO)
		var packed := PackedScene.new()
		for area in fixture.get_node("Areas").get_children():
			fixture.set_editable_instance(area, true)
		assert(packed.pack(fixture) == OK)
		fixture.free()
		game.initial_level = packed
		add_child(game)
		var level := GameHandler.current_level
		var player := level.player
		player.set_physics_process(false)
		await get_tree().physics_frame
		await get_tree().process_frame
		# CharacterBody2D chooses its integration delta from the calling loop.
		# Execute sweeps during physics, matching production player movement.
		pending_sweep = func():
			assert(Engine.is_in_physics_frame())
			if trial.size() > 3:
				var used := level.world_objects.get_node("question_block_5_9") as BaseBlock
				used.state_machine.change_state(used.state_machine.get_state(&"Inactive"))
			player.body.global_position = Vector2(trial[0], 175)
			player.body.velocity = Vector2(0, -120)
			player.move_body()
			var reactions := 0
			for block in level.world_objects.get_children():
				if block.state_machine.current_state.name == &"Bouncing":
					reactions += 1
			assert(
				reactions == (1 if trial[2] else 0),
				"Bonk edge/seam trial failed at X=%s" % trial[0]
			)
			assert(player.body.is_on_ceiling() == (trial[2] or trial.size() > 3))
			if trial[1] and trial[2]:
				var expected := "brick_4_9" if trial[0] < 80.0 else "brick_5_9"
				assert(
					(
						level.world_objects.get_node(expected).state_machine.current_state.name
						== &"Bouncing"
					),
					"Wrong seam target at X=%s" % trial[0]
				)
			# Horizontal side contacts are never offensive ceiling contacts.
			player.body.global_position = Vector2(57, 157)
			player.body.velocity = Vector2(180, 0)
			player.move_body()
			assert(not player.bonk_action.deliver(player))
		await sweep_finished
		game.free()
		await get_tree().physics_frame
		await get_tree().process_frame
	await _test_hidden_block()
	print(
		"PASS: Regular bonk edges and seams, hidden-block side and top pass-through, shared bonk response, and used-block landing."
	)
	get_tree().quit()


func _test_hidden_block() -> void:
	var level := preload("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	level.entity_layout.clear()
	level.entity_layout.set_cell(Vector2i(8, 8), 9, Vector2i.ZERO)
	level.entity_layout.set_cell(Vector2i(10, 8), 1, Vector2i.ZERO)
	add_child(level)
	var player := level.player
	player.set_physics_process(false)
	var block := level.world_objects.get_node("hidden_question_block_8_8") as HiddenQuestionBlock
	await get_tree().physics_frame
	pending_sweep = func():
		player.body.global_position = Vector2(121, 142)
		player.body.velocity = Vector2(360, 0)
		player.move_body()
		assert(not player.body.is_on_wall() and player.body.global_position.x > 121.0)
		player.body.global_position = Vector2(136, 126)
		player.body.velocity = Vector2(0, 240)
		player.move_body()
		assert(not player.body.is_on_floor() and player.body.global_position.y > 128.0)
		assert(block.state_machine.current_state.name == &"Active")
		var coins := GameHandler.player_status.coins
		player.body.global_position = Vector2(136, 160)
		player.body.velocity = Vector2(0, -240)
		player.move_body()
		assert(block.state_machine.current_state.name == &"Bouncing")
		assert(GameHandler.player_status.coins == coins + 1)
		var hidden_stop := player.body.global_position.y
		var hidden_speed := player.body.velocity.y
		player.body.global_position = Vector2(168, 160)
		player.body.velocity = Vector2(0, -240)
		player.move_body()
		assert(player.body.is_on_ceiling())
		assert(absf(player.body.global_position.y - hidden_stop) < 0.1)
		assert(player.body.velocity.y == hidden_speed)
	await sweep_finished
	await get_tree().physics_frame
	pending_sweep = func():
		player.body.global_position = Vector2(136, 126)
		player.body.velocity = Vector2(0, 240)
		player.move_body()
		assert(player.body.is_on_floor())
	await sweep_finished
	level.free()
