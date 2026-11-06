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
	print(
		"PASS: Bonk accepts real ceiling edge hits, selects one seam target, and ignores escaped corners and side hits."
	)
	get_tree().quit()
