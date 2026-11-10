extends Node

signal tick_finished


func _physics_process(_delta: float) -> void:
	tick_finished.emit()


func ticks(count: int = 1) -> void:
	for frame in range(count):
		await tick_finished


func reset_trial(player: BasePlayer) -> void:
	player.set_physics_process(false)
	if player.state_machine.current_state == player.climb_state:
		assert(player.state_machine.change_state(player.climb_state.move_state))
	player.body.global_position = Vector2(40, 130)
	player.body.velocity = Vector2.ZERO
	await ticks(3)
	# Let normal player processing observe separation even after a same-tick test grab.
	player.set_physics_process(true)
	await ticks()
	player.set_physics_process(false)
	assert(player.state_machine.change_state(player.climb_state.move_state))


func _ready() -> void:
	process_physics_priority = 200
	var fixture := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	fixture.timer_enabled = false
	fixture.get_node("Players/PlayerSpawn").position = Vector2(40, 208)
	var main := fixture.get_node("Areas/MainArea") as BaseLevelArea
	main.pipe_routes = []
	main.transport_points = []
	main.get_node("Camera2D").area_right = 256
	var ground := main.get_node("Layouts/GroundLayout") as TileMapLayer
	ground.clear()
	for x in range(16):
		ground.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
	var layout := main.get_node("Layouts/EntityLayout") as TileMapLayer
	layout.clear()
	layout.set_cell(Vector2i(6, 2), 5, Vector2i.ZERO)
	for area in fixture.get_node("Areas").get_children():
		fixture.set_editable_instance(area, true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	game.stages.assign([packed])
	add_child(game)
	var player := GameHandler.current_level.player
	var pole := (
		GameHandler.current_level.active_area.get_node("WorldObjects/flagpole_6_2") as BaseClimbable
	)
	await ticks(3)
	# One real movement tick crosses into the shaft from outside the capture band.
	# Include the solid base's top and the collision-margin/landing edge beneath it.
	for height in [40.0, 47.5, 60.0, 130.0, 191.92, 192.0, 193.5]:
		for direction in [-1.0, 1.0]:
			for speed in [90.0, 150.0]:
				await reset_trial(player)
				player.body.global_position = Vector2(109.9 if direction > 0.0 else 130.1, height)
				player.body.velocity = Vector2(direction * speed, 0.0)
				player.face_direction(direction)
				assert(
					not pole.can_attach(player), "Trial must begin outside narrow shaft contact."
				)
				var action := "ui_right" if direction > 0.0 else "ui_left"
				Input.action_press(action)
				Input.action_press("secondary")
				player.set_physics_process(true)
				await ticks()
				player.set_physics_process(false)
				Input.action_release(action)
				Input.action_release("secondary")
				assert(
					player.state_machine.current_state == player.climb_state,
					"Missed capture y=%s dir=%s speed=%s" % [height, direction, speed]
				)
				assert(player.climbing.get_surface() == pole)
				if height < 50.0:
					assert(
						player.body.global_position.y < 50.0,
						"A ball grab must not be clamped down to the old 56px limit."
					)
				assert(
					is_equal_approx(
						player.body.global_position.x, 113.0 if direction > 0.0 else 127.0
					)
				)
	# At the highest valid grab, the lower side probe touches the ball's top row.
	await reset_trial(player)
	player.body.global_position = Vector2(113, 40)
	assert(pole.can_attach(player))
	player._try_attach_climbable(player.body.global_position, player.body.global_position)
	assert(player.body.global_position.y == 40.0)
	await reset_trial(player)
	player.body.global_position = Vector2(113, 39)
	assert(not pole.can_attach(player), "Being entirely above the ball must not grab it.")
	# Standing on the base must grab immediately from any position crossing its shaft.
	for offset in [-9.0, -7.0, 6.0, 9.0]:
		await reset_trial(player)
		player.body.global_position = Vector2(120 + offset, 191.92)
		player.set_physics_process(true)
		await ticks()
		player.set_physics_process(false)
		assert(player.state_machine.current_state == player.climb_state)
	# Reference low-nibble acceptance: the old envelope rejected the early left band.
	await reset_trial(player)
	for offset in [-10.0, -9.0, -8.0, -7.0, 6.0, 7.0, 8.0, 9.0]:
		player.body.global_position = Vector2(120 + offset, 100)
		assert(pole.can_attach(player), "Reference grab offset rejected: %s" % offset)
	for offset in [-11.0, -6.0, -1.0, 0.0, 5.0, 10.0]:
		player.body.global_position = Vector2(120 + offset, 100)
		assert(not pole.can_attach(player), "Outside reference grab bands: %s" % offset)
	# A descending grab preserves the accepted end-of-tick height.
	await reset_trial(player)
	player.body.global_position = Vector2(112, 76)
	player._try_attach_climbable(Vector2(109, 70), player.body.global_position)
	assert(player.climbing.get_surface() == pole)
	assert(is_equal_approx(player.body.global_position.y, 76.0))
	# A low side probe can reach the shaft while feet are below the base top.
	await reset_trial(player)
	player.body.global_position = Vector2(113, 194)
	player._try_attach_climbable(player.body.global_position, player.body.global_position)
	assert(player.climbing.get_surface() == pole)
	assert(player.body.global_position.y == 194.0)
	# Landing in the gap between probe bands and then walking still grabs before leaving.
	await reset_trial(player)
	player.body.global_position = Vector2(120, 191.92)
	player.body.velocity = Vector2(90, 0)
	Input.action_press("ui_right")
	player.set_physics_process(true)
	await ticks(6)
	player.set_physics_process(false)
	Input.action_release("ui_right")
	assert(player.climbing.get_surface() == pole)
	# A real running jump from a reference-height step reaches above the old clamp.
	await reset_trial(player)
	var platform := StaticBody2D.new()
	var platform_shape := CollisionShape2D.new()
	var platform_rect := RectangleShape2D.new()
	platform_rect.size = Vector2(32, 16)
	platform_shape.shape = platform_rect
	platform.add_child(platform_shape)
	platform.position = Vector2(32, 136)
	GameHandler.current_level.add_child(platform)
	player.body.global_position = Vector2(32, 128)
	player.body.velocity = Vector2(0, 1)
	player.body.move_and_slide()
	await ticks(2)
	assert(player.body.is_on_floor())
	player.body.velocity.x = 150.0
	Input.action_press("ui_right")
	Input.action_press("secondary")
	Input.action_press("primary")
	player.set_physics_process(true)
	for frame in range(50):
		await ticks()
		if player.state_machine.current_state == player.climb_state:
			break
	Input.action_release("ui_right")
	Input.action_release("secondary")
	Input.action_release("primary")
	player.set_physics_process(false)
	assert(player.climbing.get_surface() == pole)
	assert(
		player.body.global_position.y >= 40.0 and player.body.global_position.y < 56.0,
		"Running jump should retain a high ball grab, got %s" % player.body.global_position.y
	)
	platform.free()
	# Crossing the band without an accepted final position does not grab.
	for direction in [-1.0, 1.0]:
		await reset_trial(player)
		var start := Vector2(90 if direction > 0 else 150, 130)
		player.body.global_position = start
		player.body.velocity = Vector2(direction * 3600, 0)
		player.body.move_and_slide()
		assert(not pole.can_attach(player))
		player._try_attach_climbable(start, player.body.global_position)
		assert(player.climbing.get_surface() == null)
	# A solid wall before the shaft must prevent capture; no predicted-motion grab.
	await reset_trial(player)
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4, 32)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = Vector2(112, 122)
	GameHandler.current_level.add_child(wall)
	await ticks()
	var start := Vector2(100, 130)
	player.body.global_position = start
	player.body.velocity = Vector2(1500, 0)
	player.body.move_and_slide()
	player._try_attach_climbable(start, player.body.global_position)
	assert(player.climbing.get_surface() == null)
	wall.free()
	# Walking beside the bottom block on the lower floor is not shaft contact.
	await reset_trial(player)
	player.body.global_position = Vector2(106, 208)
	player._try_attach_climbable(player.body.global_position, player.body.global_position)
	assert(player.climbing.get_surface() == null)
	game.free()
	await ticks(2)
	print(
		"PASS: 28 real-tick captures from both directions at walk/run speed, top/middle/base/landing edges; base standing, end-of-tick sampling, wall occlusion and below-shaft rejection."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
