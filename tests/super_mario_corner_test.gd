extends Node
signal stepped
var pending: Callable
var p: Mario


func _physics_process(_d: float) -> void:
	if pending.is_valid():
		var c := pending
		pending = Callable()
		c.call()
		stepped.emit()


func step(c: Callable) -> void:
	pending = c
	await stepped


func _ready() -> void:
	process_physics_priority = 200
	ControllerHandler.set_physics_process(false)
	var level := load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	level.player_start_configuration = load("res://assets/player/forms/super.tres")
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	var floor := level.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
	floor.clear()
	for x in range(24):
		floor.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
	add_child(level)
	level.set_physics_process(false)
	level.active_area.set_physics_process(false)
	p = level.player as Mario
	p.set_physics_process(false)
	var block := (
		load("res://scenes/entities/blocks/question/question_block.tscn").instantiate() as BaseBlock
	)
	block.position = Vector2(128, 128)
	level.world_objects.add_child(block)
	block.state_machine.change_state(block.get_node("StateMachine/Inactive"))
	await get_tree().physics_frame
	await get_tree().process_frame
	for direction in [-1.0, 1.0]:
		for mode in ["corner", "last_upward_tick"]:
			for phase in range(24):
				var y: float = (
					(172.0 + phase * 0.125) if mode == "corner" else (187.8 + phase * 0.0625)
				)
				await step(
					func():
						p.bonk_action.reset_reaction_gate()
						p.vertical_movement.reset_fraction()
						p.state_machine.stop(false)
						p.body.global_position = Vector2(
							(122.0 if direction > 0 else 150.0) if mode == "corner" else 136.0, y
						)
						p.body.velocity = Vector2.ZERO
						p.body.move_and_slide()
						p.jump_action.active = true
						p.jump_action.falling_gravity = 2025
						p.jump_action.set("_released", mode == "last_upward_tick")
						p.jump_action.set("_rise", 450.0)
						p.state_machine.change_state(p.get_node("StateMachine/Jump"))
						p.body.velocity = Vector2(
							150 * direction if mode == "corner" else 0,
							-30 if mode == "corner" else -240
						)
						ControllerHandler.input_right = (
							1 if direction > 0 and mode == "corner" else 0
						)
						ControllerHandler.input_left = (
							1 if direction < 0 and mode == "corner" else 0
						)
						ControllerHandler.input_primary = mode == "corner"
						ControllerHandler.input_primary_just_pressed = false
				)
				for i in range(14):
					await step(func(): p._physics_process(1.0 / 60.0))
					var head := p.get_head_position()
					var inside := (
						head.y < 143.999 and head.y > 128 and head.x > 128 and head.x < 144
					)
					assert(
						(
							not inside
							or p.body.velocity.y >= 0
							or posmod(int(floorf(p.body.global_position.y)), 16) < 4
						),
						(
							"Overlapping head must reverse: %s direction=%s height=%s tick=%s"
							% [mode, direction, y, i]
						)
					)
				assert(
					(
						p.get_head_position().y >= 144
						or p.get_head_position().x < 128
						or p.get_head_position().x >= 144
					),
					"Head must clear naturally"
				)
	# Adjacent tile phases: below the head threshold, side collision owns contact;
	# at the threshold, an accepted question-block bounce stops Y as well as X.
	block.free()
	for direction in [-1.0, 1.0]:
		for feet_y in [163.0, 164.0]:
			var question := (
				load("res://scenes/entities/blocks/question/question_block.tscn").instantiate()
				as QuestionBlock
			)
			question.position = Vector2(128, 128)
			level.world_objects.add_child(question)
			await get_tree().physics_frame
			var coins := GameHandler.get_session_value(&"coins") as int
			var x := 129.0 if direction > 0 else 143.0
			await step(
				func():
					p.bonk_action.reset_reaction_gate()
					p.body.global_position = Vector2(x, feet_y)
					p.body.velocity = Vector2(150 * direction, -60)
					p.terrain.resolve(p, Vector2(x - 2 * direction, feet_y + 1), true, false)
			)
			assert(p.body.velocity.x == 0, "Upper side contact must stop sideways momentum")
			assert(
				is_equal_approx(p.body.global_position.x, x - direction),
				"Side contact nudges one pixel"
			)
			assert(p.body.global_position.y == feet_y, "Head response must not snap")
			if feet_y == 163:
				assert(
					p.body.velocity.y == -60 and not question._bounce_reward_claimed,
					"Phase 3 must skip head bonk"
				)
				assert(GameHandler.get_session_value(&"coins") == coins)
			else:
				assert(
					p.body.velocity.y == 0 and question._bounce_reward_claimed,
					"Phase 4 must bounce with zero Y speed"
				)
				assert(GameHandler.get_session_value(&"coins") == coins + 1)
				await step(func(): p.terrain.resolve(p, p.body.global_position, false, false))
				assert(
					GameHandler.get_session_value(&"coins") == coins + 1,
					"Sustained contact must not award twice"
				)
			question.free()
	# A thin upper obstruction is above the short support body. Both diagonal
	# entry directions must still resolve, even with next-tick downward velocity.
	var thin := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16, 2)
	collision.shape = rectangle
	collision.position = Vector2(8, 1)
	thin.add_child(collision)
	thin.position = Vector2(128, 128)
	level.world_objects.add_child(thin)
	await get_tree().physics_frame
	for direction in [-1.0, 1.0]:
		await step(
			func():
				p.bonk_action.reset_reaction_gate()
				p.body.global_position = Vector2(136, 157)
				p.body.velocity = Vector2(150 * direction, 3.75)
				p.terrain.resolve(p, Vector2(136 - 2 * direction, 157.5), true, false)
		)
		assert(is_equal_approx(p.get_head_position().y, 129), "Bonk must not snap position")
		assert(p.body.velocity.y == 63.75, "Thin upper-body ceiling must reverse velocity")
	thin.free()
	ControllerHandler.input_left = 0
	ControllerHandler.input_right = 0
	ControllerHandler.input_primary = false
	level.free()
	ControllerHandler.set_physics_process(true)
	print("super_mario_corner_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
