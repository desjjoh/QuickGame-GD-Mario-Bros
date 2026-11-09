extends Node2D

const POPUP := preload("res://scenes/components/presentation/score_popup.tscn")

signal tick_finished


func _physics_process(_delta: float) -> void:
	tick_finished.emit()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Sample after the popup's update even when one rendered frame runs several physics ticks.
	process_physics_priority = 200
	var world := Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.position = Vector2(19, 31)
	add_child(world)
	var rows := [[100, 1000], [200, 2000], [400, 4000], [500, 5000], [800, 8000]]
	for row in range(rows.size()):
		for column in range(2):
			var popup = POPUP.instantiate()
			world.add_child(popup)
			assert(not popup.visible)
			var point := Vector2(80 + column * 40, 48 + row * 16)
			assert(popup.show_score(rows[row][column], point))
			assert(popup.visible and popup.global_position == point)
			assert(popup.region_rect == Rect2(column * 16, row * 8, 16, 8))
	var extra_life = POPUP.instantiate()
	world.add_child(extra_life)
	extra_life.show_one_up(Vector2(120, 128))
	assert(extra_life.visible and extra_life.global_position == Vector2(120, 128))
	assert(extra_life.region_rect == Rect2(16, 40, 16, 8))
	world.position.x += 10
	assert(extra_life.global_position == Vector2(130, 128))
	assert(not extra_life.show_score(300, Vector2.ZERO) and not extra_life.visible)
	extra_life.show_one_up(Vector2(120, 128))
	var score_before := GameHandler.player_status.score
	var lives_before := GameHandler.player_status.lives
	var animated = POPUP.instantiate()
	world.add_child(animated)
	assert(animated.show_score(1000, Vector2(100, 100)))
	animated.rise_and_free()
	for tick in range(1, 13):
		await tick_finished
		assert(animated.global_position == Vector2(100, 100 - tick))
	get_tree().paused = true
	var paused_position: Vector2 = animated.global_position
	for tick in range(4):
		await get_tree().process_frame
	assert(animated.global_position == paused_position)
	get_tree().paused = false
	for tick in range(13, 48):
		await tick_finished
		assert(animated.global_position == Vector2(100, 100 - tick))
	await tick_finished
	assert(animated.is_queued_for_deletion())
	await get_tree().process_frame
	assert(not is_instance_valid(animated), "The opted-in rise must free its popup")
	assert(
		is_instance_valid(extra_life) and extra_life.global_position == Vector2(120, 128),
		"Display-only popups must not animate or expire automatically"
	)
	assert(
		(
			GameHandler.player_status.score == score_before
			and GameHandler.player_status.lives == lives_before
		),
		"Popup presentation must never grant rewards"
	)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var frame := get_viewport().get_texture().get_image()
		assert(frame.save_png("res://.godot/validation/score-popup.png") == OK)
	print(
		"PASS: score artwork/placement, opt-in rise and cleanup, pause, display-only lifetime and reward separation."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
