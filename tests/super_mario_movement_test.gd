extends Node

var mario: Mario


func step(count: int = 1) -> void:
	for index in range(count):
		mario._physics_process(1.0 / 60.0)
		await get_tree().physics_frame
		await get_tree().process_frame
		ControllerHandler.input_primary_just_pressed = false


func _ready() -> void:
	ControllerHandler.set_physics_process(false)
	var level := load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	level.player_start_configuration = MarioFormPresentation.SUPER
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	var floor := level.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
	floor.clear()
	for x in range(24):
		floor.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
	add_child(level)
	level.active_area.get_node("Camera2D").follow_enabled = false
	mario = level.player as Mario
	mario.set_physics_process(false)
	mario.body.global_position = Vector2(128, 208)
	mario.body.velocity = Vector2.ZERO
	await step(2)
	assert(mario.body.is_on_floor())
	ControllerHandler.input_down = 1
	await step()
	assert(mario.form_controller.is_crouched)
	assert(mario.sprite.texture == mario.form_controller.current_form.crouch)
	assert(mario.enemy_hurtbox.get_node("CollisionShape2D").shape.size == Vector2(12, 12))
	var feet := mario.body.global_position
	ControllerHandler.input_primary = true
	ControllerHandler.input_primary_just_pressed = true
	await step()
	assert(mario.state_machine.current_state.name == &"Jump")
	assert(mario._active_sound_effect.stream == SoundHandler.get_sound(&"jump_big"))
	assert(mario.body.velocity.y < 0 and mario.form_controller.is_crouched)
	ControllerHandler.input_down = 0
	await step(3)
	assert(
		(
			mario.form_controller.is_crouched
			and mario.sprite.texture == mario.form_controller.current_form.crouch
		)
	)
	ControllerHandler.input_primary = false
	for index in range(120):
		await step()
		if mario.body.is_on_floor():
			break
	assert(mario.body.is_on_floor())
	await step()
	assert(not mario.form_controller.is_crouched)
	assert(absf(mario.body.global_position.y - feet.y) < 0.1)
	assert(mario.enemy_hurtbox.get_node("CollisionShape2D").shape.size == Vector2(12, 24))
	# Entering crouch keeps momentum; simultaneous grounded Down+Right clears crouch/input.
	mario.body.velocity.x = 60
	ControllerHandler.input_down = 1
	var x := mario.body.global_position.x
	await step()
	assert(mario.body.global_position.x > x and mario.body.velocity.x > 0)
	ControllerHandler.input_right = 1
	await step()
	assert(not mario.form_controller.is_crouched and mario.get_movement_axis() == Vector2.ZERO)
	# Down stops low-speed coasting in either direction, but released input does not.
	ControllerHandler.input_right = 0
	for direction in [-1.0, 1.0]:
		ControllerHandler.input_down = 0
		mario.body.velocity.x = 30.0 * direction
		await step()
		assert(mario.body.velocity.x * direction > 0.0)
		ControllerHandler.input_down = 1
		await step()
		assert(is_zero_approx(mario.body.velocity.x))
		assert(mario.form_controller.is_crouched)
		# Above the cutoff, crouching retains momentum with normal friction.
		mario.body.velocity.x = 60.0 * direction
		await step()
		assert(mario.body.velocity.x * direction > 41.25)
	ControllerHandler.input_down = 0
	ControllerHandler.input_right = 0
	# Super reuses normal run acceleration and the selected walk artwork.
	mario.body.velocity = Vector2.ZERO
	ControllerHandler.input_right = 1
	ControllerHandler.input_secondary = true
	await step(40)
	assert(mario.body.velocity.x > 105)
	assert(mario.sprite.texture in mario.form_controller.current_form.walk)
	ControllerHandler.input_right = 0
	ControllerHandler.input_secondary = false
	# Uncrouching under an upper obstruction stands immediately and nudges left one pixel.
	var obstacle := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16, 16)
	shape.shape = rectangle
	obstacle.add_child(shape)
	obstacle.position = Vector2(152, 184)
	level.world_objects.add_child(obstacle)
	mario.body.global_position = Vector2(140, 208)
	mario.body.velocity = Vector2.ZERO
	mario.form_controller.set_crouched(true)
	await get_tree().physics_frame
	await get_tree().process_frame
	await step()
	assert(not mario.form_controller.is_crouched)
	assert(mario.body.global_position.x == 139 and absf(mario.body.global_position.y - 208) < 0.1)
	obstacle.free()
	# Same controlled geometry as Mesen: right obstruction, left obstruction, enclosure.
	for trial in [[64.0, 16.0, 64.0, 58.0], [32.0, 16.0, 48.0, 54.0], [48.0, 32.0, 64.0, 86.0]]:
		var wall := StaticBody2D.new()
		var wall_shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(trial[1], 16)
		wall_shape.shape = box
		wall.add_child(wall_shape)
		wall.position = Vector2(trial[0] + trial[1] / 2.0, 184)
		level.world_objects.add_child(wall)
		mario.body.global_position = Vector2(trial[2], 208)
		var before_correction := mario.camera_correction_x
		mario.body.velocity = Vector2.ZERO
		await get_tree().physics_frame
		await get_tree().process_frame
		await step(28)
		assert(is_equal_approx(mario.body.global_position.x, trial[3]))
		assert(
			absf((mario.camera_correction_x - before_correction) - (trial[3] - trial[2])) < 0.1,
			"Stationary Super push-out must be excluded from camera progress."
		)
		wall.free()

	# Super's center head, fourteen pixels above the support body's head, bonks a block.
	var block := (
		load("res://scenes/entities/blocks/question/question_block.tscn").instantiate()
		as QuestionBlock
	)
	block.position = Vector2(128, 144)
	level.world_objects.add_child(block)
	mario.body.global_position = Vector2(136, 208)
	mario.body.velocity = Vector2.ZERO
	assert(mario.state_machine.change_state(mario.get_node("StateMachine/Idle")))
	await step(2)
	ControllerHandler.input_primary = true
	ControllerHandler.input_primary_just_pressed = true
	for index in range(30):
		await step()
		if block._bounce_reward_claimed:
			break
	assert(block._bounce_reward_claimed and mario.body.global_position.y >= 188)
	ControllerHandler.input_primary = false
	block.free()
	mario.body.global_position = Vector2(136, 208)
	mario.body.velocity = Vector2.ZERO
	assert(mario.state_machine.change_state(mario.get_node("StateMachine/Idle")))
	await step(2)
	# The same standing head offset must reveal hidden blocks, not the short core head.
	var hidden := (
		load("res://scenes/entities/blocks/question/hidden_question_block.tscn").instantiate()
		as HiddenQuestionBlock
	)
	hidden.position = Vector2(128, 144)
	level.world_objects.add_child(hidden)
	await step(2)
	ControllerHandler.input_primary = true
	ControllerHandler.input_primary_just_pressed = true
	for index in range(30):
		await step()
		if hidden._bounce_reward_claimed:
			break
	assert(hidden._bounce_reward_claimed and mario.body.global_position.y >= 188)
	ControllerHandler.input_primary = false
	mario.body.global_position = Vector2(136, 208)
	mario.body.velocity = Vector2.ZERO
	assert(mario.state_machine.change_state(mario.get_node("StateMachine/Idle")))
	ControllerHandler.input_down = 1
	await step(2)
	ControllerHandler.input_primary = true
	ControllerHandler.input_primary_just_pressed = true
	var highest_feet := mario.body.global_position.y
	for index in range(30):
		await step()
		highest_feet = minf(highest_feet, mario.body.global_position.y)
		if mario.body.velocity.y > 0 and not mario.body.is_on_floor():
			break
	assert(highest_feet >= 173.9 and highest_feet <= 174.1)
	assert(mario.form_controller.is_crouched)
	ControllerHandler.input_primary = false
	ControllerHandler.input_down = 0
	ControllerHandler.input_right = 0
	ControllerHandler.set_physics_process(true)
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("super_mario_movement_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
