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
	var level := load("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
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
	for form in [preload("res://assets/player/forms/small.tres"), MarioFormPresentation.SUPER]:
		mario.form_controller.configure(mario, form)
		for direction in [-1.0, 1.0]:
			ControllerHandler.input_left = maxf(-direction, 0)
			ControllerHandler.input_right = maxf(direction, 0)
			ControllerHandler.input_down = 1
			mario.sprite.flip_h = direction < 0
			mario.run_action.running_history = false
			mario.body.velocity = Vector2.ZERO
			await step()
			assert(
				mario.body.velocity.x == 0, "Down+direction must not start walking in either form."
			)
			assert(not mario.form_controller.is_crouched)
			for run in [false, true]:
				ControllerHandler.input_secondary = run
				mario.body.velocity.x = 30 * direction
				await step()
				assert(mario.body.velocity.x * direction > 0)
				assert(
					mario.body.velocity.x * direction < 30,
					"Filtered controls must coast, not accelerate."
				)
			ControllerHandler.input_secondary = false
			# Down with the opposite raw direction retains the reference low-speed stop.
			mario.body.velocity.x = -30 * direction
			await step()
			assert(mario.body.velocity.x == 0)
			ControllerHandler.input_left = 0
			ControllerHandler.input_right = 0
			mario.body.velocity.x = 30 * direction
			await step()
			assert(mario.body.velocity.x == 0, "Down alone must still stop low-speed coasting.")
			assert(mario.form_controller.is_crouched == form.can_crouch)
			# Adding direction clears a grounded crouch; Jump remains usable.
			ControllerHandler.input_left = maxf(-direction, 0)
			ControllerHandler.input_right = maxf(direction, 0)
			ControllerHandler.input_primary = true
			ControllerHandler.input_primary_just_pressed = true
			await step()
			assert(mario.state_machine.current_state.name == &"Jump")
			assert(mario.body.velocity.y < 0 and not mario.form_controller.is_crouched)
			assert(not mario.body.is_on_floor())
			assert(
				mario.get_movement_axis().x == direction,
				"Air steering must remain available with Down."
			)
			await step(2)
			assert(mario.body.velocity.x * direction > 0)
			ControllerHandler.input_primary = false
			ControllerHandler.input_left = 0
			ControllerHandler.input_right = 0
			ControllerHandler.input_down = 0
			mario.body.global_position = Vector2(128, 208)
			mario.body.velocity = Vector2.ZERO
			mario.state_machine.change_state(mario.get_node("StateMachine/Idle"))
			await step(2)
	ControllerHandler.set_physics_process(true)
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("down_direction_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
