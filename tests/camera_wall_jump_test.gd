extends Node

signal physics_step_finished

var level: BaseLevel
var recording: bool = false
var release_primary_after_step: bool = false
var jump_ticks: int = 0
var min_x: float
var max_x: float


func _physics_process(_delta: float) -> void:
	# Bound a short tap to one player physics step even if rendering stalls.
	if release_primary_after_step:
		Input.action_release(ControllerHandler.primary_action)
		release_primary_after_step = false
	if recording:
		if level.player.state_machine.current_state is MarioJumpState:
			jump_ticks += 1
		min_x = minf(min_x, level.player.body.global_position.x)
		max_x = maxf(max_x, level.player.body.global_position.x)
	physics_step_finished.emit()


func ticks(count: int) -> void:
	for frame in range(count):
		await physics_step_finished


func make_game(direction: float) -> Node:
	var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
	var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	fixture.keep_player_on_screen = false
	var main := fixture.get_node("Areas/MainArea") as BaseLevelArea
	main.transport_points.clear()
	var ground := main.get_node("Layouts/GroundLayout") as TileMapLayer
	ground.clear()
	for x in range(64):
		ground.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
	ground.set_cell(Vector2i(16, 12), 1, Vector2i(7, 1))
	ground.set_cell(Vector2i(17, 12), 1, Vector2i(8, 1))
	var markers := main.get_node("Layouts/EntityLayout") as TileMapLayer
	markers.clear()
	markers.set_cell(Vector2i(16, 10), 3, Vector2i.ZERO)
	fixture.get_node("Players/PlayerSpawn").position = Vector2(200 if direction > 0 else 336, 208)
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area, true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	game.stages.assign([packed])
	return game


func _ready() -> void:
	process_physics_priority = 200
	for direction in [1.0, -1.0]:
		for running in [false, true]:
			var game := make_game(direction)
			add_child(game)
			level = GameHandler.current_level
			var camera := level.active_area.get_node("Camera2D") as LevelCamera
			camera.snap_to_arrival(level.player.body)
			await ticks(5)
			var action: StringName = (
				ControllerHandler.right_action if direction > 0 else ControllerHandler.left_action
			)
			Input.action_press(action)
			if running:
				Input.action_press(ControllerHandler.secondary_action)
			await ticks(80)
			var before := camera.global_position.x
			min_x = level.player.body.global_position.x
			max_x = min_x
			jump_ticks = 0
			recording = true
			for cycle in range(3):
				Input.action_press(ControllerHandler.primary_action)
				release_primary_after_step = true
				await ticks(1)
				Input.action_release(ControllerHandler.primary_action)
				await ticks(35)
			recording = false
			assert(
				jump_ticks > 0,
				"The regression must execute real jump physics, not merely stand at the wall."
			)
			assert(
				max_x - min_x < 0.12,
				(
					"Short hops must remain blocked: dir=%s run=%s X range=%s"
					% [direction, running, max_x - min_x]
				)
			)
			assert(
				camera.global_position.x - before < 0.12,
				(
					"Camera ratcheted while blocked: direction=%s run=%s body range=%s camera drift=%s"
					% [direction, running, max_x - min_x, camera.global_position.x - before]
				)
			)
			if direction > 0:
				Input.action_press(ControllerHandler.primary_action)
				await ticks(60)
				Input.action_release(ControllerHandler.primary_action)
				assert(
					level.player.body.global_position.x > max_x + 8,
					"A full jump must clear the pipe."
				)
				assert(
					camera.global_position.x > before + 8,
					"Legitimate new rightward progress must still scroll."
				)
			Input.action_release(action)
			Input.action_release(ControllerHandler.secondary_action)
			game.free()
			await ticks(6)
			await get_tree().process_frame
	print(
		"PASS: blocked pipe hops do not ratchet the camera in either direction at walk/run speeds; clearing the pipe resumes rightward scrolling."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
