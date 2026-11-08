extends Node
## Isolated copies of the two user-supplied jump layouts; authored stages are untouched.
signal tick_finished


func _physics_process(_delta: float) -> void:
	tick_finished.emit()


func tick() -> void:
	await tick_finished


func _ready() -> void:
	process_physics_priority = 200
	var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	fixture.timer_enabled = false
	var main := fixture.get_node("Areas/MainArea") as BaseLevelArea
	main.pipe_routes = []
	main.transport_points = []
	var ground := main.get_node("Layouts/GroundLayout") as TileMapLayer
	ground.clear()
	for x in range(96, 190):
		ground.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
	for x in [178, 179]:
		ground.set_cell(Vector2i(x, 11), 1, Vector2i(7 if x == 178 else 8, 0))
		ground.set_cell(Vector2i(x, 12), 1, Vector2i(7 if x == 178 else 8, 1))
	for x in range(180, 189):
		for y in range(maxi(5, 192 - x), 13):
			ground.set_cell(Vector2i(x, y), 0, Vector2i(0, 1))
	var layout := main.get_node("Layouts/EntityLayout") as TileMapLayer
	layout.clear()
	# Use the existing marker IDs rather than assuming their numeric identity.
	var original := load("res://scenes/levels/worlds/world 1/1-1.tscn").instantiate() as BaseLevel
	var authored := original.get_node("Areas/MainArea/Layouts/EntityLayout") as TileMapLayer
	for cell in [
		Vector2i(100, 9),
		Vector2i(101, 9),
		Vector2i(106, 9),
		Vector2i(109, 9),
		Vector2i(112, 9),
		Vector2i(109, 5)
	]:
		layout.set_cell(
			cell,
			authored.get_cell_source_id(cell),
			authored.get_cell_atlas_coords(cell),
			authored.get_cell_alternative_tile(cell)
		)
	original.free()
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area, true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
	game.stages.assign([packed])
	add_child(game)
	var level := GameHandler.current_level
	level.keep_player_on_screen = false
	level.fall_death_enabled = false
	level.set_physics_process(false)
	var player := level.player
	player.jump_action.sound_effect = null
	player.ceiling_bump_sound = null
	player.set_physics_process(false)
	ControllerHandler.set_physics_process(false)
	ControllerHandler.input_right = 1
	ControllerHandler.input_left = 0
	ControllerHandler.input_secondary = true
	ControllerHandler.input_primary = true
	ControllerHandler.input_primary_just_pressed = false
	for frame in range(3):
		await tick()
	for trial in [
		[2876.0, 176.0, 96.0, false],
		[2879.0, 176.0, 96.0, true],
		[2882.0, 176.0, 96.0, true],
		[1630.0, 144.0, 80.0, false],
		[1634.0, 144.0, 80.0, false],
		[1636.0, 144.0, 80.0, false]
	]:
		player.state_machine.stop(false)
		player.body.global_position = Vector2(trial[0], trial[1] - 0.1)
		player.body.velocity = Vector2(0, 60)
		await tick()
		player.move_body()
		assert(player.body.is_on_floor())
		var origin := player.body.global_position
		player.body.velocity = Vector2(150, 0)
		assert(player.jump_action.begin(player.motion_values))
		assert(player.state_machine.change_state(player.state_machine.get_state(&"Jump")))
		var peak := origin.y
		var landed := false
		for frame in range(65):
			await tick()
			player.state_machine.process_physics(1.0 / 60.0)
			peak = minf(peak, player.body.global_position.y)
			if frame == 0:
				assert(absf(origin.y - player.body.global_position.y - 5.0) < 0.1)
				assert(is_equal_approx(player.body.velocity.y, -290.625))
			if frame > 0 and player.body.is_on_floor():
				assert(player.jump_action.falling_gravity == 2025.0)
				var reached := absf(player.body.global_position.y - float(trial[2])) < 0.2
				assert(
					reached == trial[3],
					(
						"Unexpected benchmark landing at takeoff X=%s, landing=%s"
						% [trial[0], player.body.global_position]
					)
				)
				landed = true
				break
		if not landed:
			print(
				(
					"BENCHMARK missing landing: trial=%s body=%s velocity=%s floorcell=%s"
					% [
						trial,
						player.body.global_position,
						player.body.velocity,
						level.active_area.get_node("Layouts/GroundLayout").get_cell_source_id(
							Vector2i(185, 7)
						)
					]
				)
			)
		assert(landed)
		# Jump initialization aligns feet to an integer; floor support retains a safe margin.
		assert(roundf(origin.y) - peak == 83.0, "Full-speed held jump must rise 83 logical pixels.")
	ControllerHandler.input_right = 0
	ControllerHandler.input_primary = false
	ControllerHandler.input_secondary = false
	player.state_machine.stop(false)
	game.free()
	await get_tree().process_frame
	print(
		"PASS: full-speed launch/apex, tight staircase landing, early staircase misses, and upper question-block rejection across six takeoff positions."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
