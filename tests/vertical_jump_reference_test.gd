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
	var level := load("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
	level.player_start_configuration = load("res://assets/player/forms/super.tres")
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	var terrain := level.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
	terrain.clear()
	for cell in range(24):
		terrain.set_cell(Vector2i(cell, 13), 0, Vector2i.ZERO)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(level)
	level.set_physics_process(false)
	level.active_area.set_physics_process(false)
	p = level.player as Mario
	p.set_physics_process(false)
	var block := (
		load("res://scenes/entities/blocks/brick/brick_block.tscn").instantiate() as BaseBlock
	)
	block.position = Vector2(352, 144)
	level.world_objects.add_child(block)
	# Fixture camera is not following the manually stepped player. Keep this observed block active.
	block.set_activity_suspended(false)
	ControllerHandler.input_left = 0
	ControllerHandler.input_right = 0
	ControllerHandler.input_primary = false
	await step(
		func():
			p.body.global_position = Vector2(360, 208)
			p.body.velocity = Vector2.ZERO
			p.body.move_and_slide()
			p.state_machine.change_state(p.get_node("StateMachine/Idle"))
	)
	await step(func(): p._physics_process(1.0 / 60.0))
	ControllerHandler.input_primary = true
	ControllerHandler.input_primary_just_pressed = true
	# Frames 930–935 from the input-only natural-growth trace, converted to feet.
	var expected_y := [204.0, 200.0, 196.0, 192.0, 189.0, 185.0]
	var expected_fraction := [32, 64, 96, 128, 160, 192]
	var expected_position_fraction := [0, 32, 96, 192, 64, 224]
	for tick in range(6):
		await step(func(): p._physics_process(1.0 / 60.0))
		ControllerHandler.input_primary_just_pressed = false
		assert(
			p.body.global_position.y == expected_y[tick],
			(
				"Normal Mesen jump Y tick %s actual %s expected %s"
				% [tick, p.body.global_position.y, expected_y[tick]]
			)
		)
		assert(p.vertical_movement.speed_fraction == expected_fraction[tick])
		assert(p.vertical_movement.position_fraction == expected_position_fraction[tick])
	assert(not block.visible and p.body.velocity.y == -75, "Shatter retains fraction 192/256")
	for expected in [[184, 1, 224, 160], [186, 2, 80, 128], [188, 2, 192, 208], [191, 3, 48, 144]]:
		await step(func(): p._physics_process(1.0 / 60.0))
		assert(p.body.global_position.y == expected[0], "Exact Mesen post-break position")
		assert(floori(p.body.velocity.y / 60.0) == expected[1], "Exact Mesen speed byte")
		assert(p.vertical_movement.speed_fraction == expected[2])
		assert(p.vertical_movement.position_fraction == expected[3])
	ControllerHandler.input_primary = false
	canvas.free()
	ControllerHandler.set_physics_process(true)
	print("vertical_jump_reference_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
