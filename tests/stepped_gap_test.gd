extends Node

signal physics_step_finished
var failures: Array[String] = []


func _physics_process(_delta: float) -> void:
	physics_step_finished.emit()


func ticks(count: int) -> void:
	for frame in range(count):
		await physics_step_finished


func make_game(direction: float, phase: float) -> Node:
	var game := load("res://tests/fixtures/silent_game.tscn").instantiate() as Node
	var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	fixture.keep_player_on_screen = false
	var main := fixture.get_node("Areas/MainArea") as BaseLevelArea
	var floor := main.get_node("Layouts/GroundLayout") as TileMapLayer
	floor.clear()
	for x in range(32):
		floor.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
	var markers := main.get_node("Layouts/EntityLayout") as TileMapLayer
	markers.clear()
	# Match the screenshot: a 32px gap with the pipe top 16px lower.
	for x in range(4, 11) if direction > 0 else range(15, 22):
		for y in [10, 11, 12]:
			markers.set_cell(Vector2i(x, y), 2, Vector2i.ZERO)
	var pipe_cell := Vector2i(13 if direction > 0 else 11, 11)
	markers.set_cell(pipe_cell, 4, Vector2i.ZERO)
	var pipe_config := TransportPlacement.new()
	pipe_config.cell = pipe_cell
	pipe_config.entrance_enabled = false
	main.transport_points = [pipe_config]
	main.get_node("Camera2D").follow_enabled = false
	fixture.get_node("Players/PlayerSpawn").position = Vector2(
		(160 if direction > 0 else 256) + direction * phase, 160
	)
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
		for phase in [0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.49]:
			var game := make_game(direction, phase)
			add_child(game)
			var player := GameHandler.current_player
			await ticks(5)
			assert(player.body.is_on_floor())
			var action: StringName = (
				ControllerHandler.right_action if direction > 0 else ControllerHandler.left_action
			)
			Input.action_press(action)
			Input.action_press(ControllerHandler.secondary_action)
			player.body.velocity.x = direction * 150.0
			player.face_direction(direction)
			player.state_machine.change_state(player.state_machine.get_state(&"Move"))
			var failed := false
			for frame in range(25):
				await ticks(1)
				if not failed and absf(player.body.velocity.x) < 140.0:
					failures.append(
						(
							"dir=%s phase=%s frame=%s position=%s velocity=%s"
							% [
								direction,
								phase,
								frame,
								player.body.global_position,
								player.body.velocity
							]
						)
					)
					failed = true
			if not player.body.is_on_floor() or absf(player.body.global_position.y - 176.0) > 0.2:
				failures.append(
					(
						"did not settle on pipe: dir=%s phase=%s position=%s"
						% [direction, phase, player.body.global_position]
					)
				)
			Input.action_release(action)
			Input.action_release(ControllerHandler.secondary_action)
			game.free()
			await get_tree().process_frame
	if not failures.is_empty():
		push_error("Stepped gap failures:\n" + "\n".join(failures))
		get_tree().quit(1)
		return
	print(
		"PASS: two-tile gaps onto a one-tile-lower pipe preserve run momentum and land at eleven subpixel phases in both directions."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
