extends Node

signal physics_step_finished
var finished_count: int = 0
var finished_top: float = 0.0


func _physics_process(_delta: float) -> void:
	physics_step_finished.emit()


func ticks(count: int = 1) -> void:
	for frame in range(count):
		await physics_step_finished


func record_finish(player: BasePlayer) -> void:
	finished_count += 1
	finished_top = player.sprite.to_global(player.sprite.get_rect().position).y


func make_game() -> Node:
	var factory: Node = load("res://tests/death_test.gd").new()
	var game: Node = factory.make_game()
	factory.free()
	return game


func _ready() -> void:
	process_physics_priority = 200
	for lower_area in [false, true]:
		GameHandler.clear_session()
		var game := make_game()
		add_child(game)
		var level := GameHandler.current_level
		level.death_fallback_delay = 2.0
		if lower_area:
			assert(level.request_area_transfer(&"lower"))
			await ticks(3)
		await ticks(3)
		var player := level.player
		var dead := player.death_state as MarioDeadState
		assert(dead != null and dead.hold_frames == 16)
		var camera := get_viewport().get_camera_2d() as LevelCamera
		var camera_origin := camera.global_position
		var bottom := (
			camera.global_position.y
			+ get_viewport().get_visible_rect().size.y / camera.zoom.y / 2.0
		)
		player.body.global_position = Vector2(camera.global_position.x, bottom - 32.0)
		player.body.velocity = Vector2(150, -100)
		player.sprite.flip_h = lower_area
		var origin := player.body.global_position
		finished_count = 0
		player.death_presentation_finished.connect(record_finish.bind(player))
		assert(level.on_death(player, true))
		assert(not level.on_death(player, true))
		assert(GameHandler.player_status.lives == 1)
		assert(player.state_machine.current_state == dead and player.is_dead)
		assert(player.sprite.texture.resource_path.ends_with("mario-dead.png"))
		assert(player.body.collision_layer == 0 and player.body.collision_mask == 0)
		assert(not player.can_read_controller_input() and not dead.controls_enabled)
		for entity in level.find_children("*", "BaseEntity", true, false):
			if entity != player:
				assert(entity.gameplay_suspended)
		Input.action_press(ControllerHandler.left_action)
		Input.action_press(ControllerHandler.primary_action)
		await ticks(16)
		assert(player.body.global_position == origin and player.body.velocity == Vector2.ZERO)
		assert(finished_count == 0 and camera.global_position == camera_origin)
		await ticks()
		assert(is_equal_approx(player.body.global_position.y, origin.y - 4.0))
		assert(is_equal_approx(player.body.velocity.y, -230.625))
		assert(player.sprite.flip_h == lower_area)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			assert(
				(
					get_viewport().get_texture().get_image().save_png(
						"res://.godot/validation/dead-state-%s.png" % lower_area
					)
					== OK
				)
			)
		var minimum_y := player.body.global_position.y
		var old_player: WeakRef = weakref(player)
		for frame in range(120):
			await ticks()
			assert(camera.global_position == camera_origin)
			if level.player == null:
				break
			minimum_y = minf(minimum_y, player.body.global_position.y)
			assert(player.body.global_position.x == origin.x)
			assert(player.body.velocity.y <= 240.0)
		assert(minimum_y < origin.y - 48.0 and minimum_y > origin.y - 60.0)
		assert(finished_count == 1 and level.player == null)
		assert(finished_top > bottom and finished_top < bottom + 5.0)
		assert(
			GameHandler.current_level == level,
			"Presentation and level delay are independent gates."
		)
		Input.action_release(ControllerHandler.left_action)
		Input.action_release(ControllerHandler.primary_action)
		await ticks(2)
		assert(old_player.get_ref() == null)
		for frame in range(120):
			await ticks()
			if GameHandler.current_level != level:
				break
		assert(GameHandler.current_level != level)
		assert(GameHandler.current_level.active_area.area_id == &"main")
		assert(not GameHandler.current_player.is_dead)
		assert(GameHandler.current_player.body.collision_mask != 0)
		assert(GameHandler.player_status.lives == 1)
		game.free()
		await ticks(2)
	# A visible final-attempt death uses the same game-over/title/reset lifecycle.
	var final_game := make_game()
	add_child(final_game)
	GameHandler.set_lives(0)
	assert(GameHandler.current_level.on_death(GameHandler.current_player, true))
	assert(GameHandler.player_status.lives == -1)
	for frame in range(180):
		await ticks()
		if GameHandler.flow == GameHandler.GameFlow.TITLE:
			break
	assert(GameHandler.flow == GameHandler.GameFlow.TITLE)
	assert(GameHandler.player_status.lives == 2)
	assert(GameHandler.current_player.gameplay_suspended)
	final_game.free()
	await ticks(2)
	# The non-presented pit path remains immediate and never enters Dead.
	var game := make_game()
	add_child(game)
	var level := GameHandler.current_level
	assert(level.on_death(level.player, false))
	assert(level.player == null)
	game.free()
	await ticks(3)
	print(
		"PASS: 16-frame death hold, dedicated launch/gravity/cap, input/collision bypass, both area cameras, full offscreen presentation, once-only cleanup and respawn, unchanged pit path."
	)
	get_tree().quit()
