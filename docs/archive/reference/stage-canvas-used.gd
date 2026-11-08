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
	var level := load("res://scenes/levels/worlds/world 1/1-1.tscn").instantiate() as BaseLevel
	level.player_start_configuration = load("res://assets/player/forms/super.tres")
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	var game_canvas := CanvasLayer.new()
	add_child(game_canvas)
	game_canvas.add_child(level)
	var used := level.world_objects.get_node("question_block_22_5") as QuestionBlock
	used.state_machine.change_state(used.get_node("StateMachine/Inactive"))
	level.set_physics_process(false)
	level.active_area.set_physics_process(false)
	p = level.player as Mario
	p.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().process_frame
	var f := FileAccess.open("res://docs/archive/reference/stage-canvas-used.csv", FileAccess.WRITE)
	f.store_line("case,step,x,feet,vx,vy,head_inside,bounce_running")
	var k := 0
	for direction in [1.0, -1.0]:
		for start_x in [320.0, 328.0, 336.0, 344.0, 352.0, 360.0, 368.0, 376.0, 384.0]:
			k += 1
			await step(
				func():
					p.state_machine.stop(false)
					p.body.global_position = Vector2(start_x, 144)
					p.body.velocity = Vector2.ZERO
					p.body.move_and_slide()
					p.state_machine.change_state(p.get_node("StateMachine/Idle"))
					ControllerHandler.input_primary = false
					ControllerHandler.input_primary_just_pressed = false
					ControllerHandler.input_right = 0
					ControllerHandler.input_left = 0
			)
			await step(func(): p._physics_process(1.0 / 60.0))
			await step(
				func():
					p.body.velocity.x = 150 * direction
					ControllerHandler.input_right = 1 if direction > 0 else 0
					ControllerHandler.input_left = 1 if direction < 0 else 0
					ControllerHandler.input_primary = true
					ControllerHandler.input_primary_just_pressed = true
					p._physics_process(1.0 / 60.0)
					ControllerHandler.input_primary_just_pressed = false
			)
			for i in range(45):
				await step(func(): p._physics_process(1.0 / 60.0))
				var pos := p.body.global_position
				f.store_line(
					(
						"%s,%s,%.6f,%.6f,%.6f,%.6f,%s,%s"
						% [
							k,
							i + 1,
							pos.x,
							pos.y,
							p.body.velocity.x,
							p.body.velocity.y,
							Rect2(352, 80, 16, 16).has_point(pos + Vector2(0, -28)),
							used.bounce.is_running()
						]
					)
				)
	f.close()
	ControllerHandler.input_left = 0
	ControllerHandler.input_right = 0
	ControllerHandler.input_primary = false
	level.free()
	ControllerHandler.set_physics_process(true)
	print("side_audit: DONE")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
