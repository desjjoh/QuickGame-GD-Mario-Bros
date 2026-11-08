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
	block.position = Vector2(128, 128)
	level.world_objects.add_child(block)
	await get_tree().physics_frame
	await get_tree().process_frame
	var f := FileAccess.open(
		"res://docs/archive/reference/break-full-jump-godot.csv", FileAccess.WRITE
	)
	f.store_line("case,step,x,feet,vx,vy,remaining")
	var row: Array[BaseBlock] = [block]
	var k := 0
	for direction in [1.0, -1.0]:
		for start_x in [88.0, 96.0, 104.0, 112.0, 120.0, 128.0, 136.0, 144.0, 152.0, 160.0]:
			k += 1
			for previous in row:
				if is_instance_valid(previous):
					previous.free()
			row.clear()
			for x in [112.0, 128.0, 144.0]:
				var brick := (
					load("res://scenes/entities/blocks/brick/brick_block.tscn").instantiate()
					as BaseBlock
				)
				brick.position = Vector2(x, 128)
				level.world_objects.add_child(brick)
				row.append(brick)
			await get_tree().physics_frame
			await step(
				func():
					p.bonk_action.reset_reaction_gate()
					p.state_machine.stop(false)
					p.body.global_position = Vector2(start_x, 208)
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
					ControllerHandler.input_primary = true
					ControllerHandler.input_primary_just_pressed = true
					ControllerHandler.input_right = 1 if direction > 0 else 0
					ControllerHandler.input_left = 1 if direction < 0 else 0
			)
			for tick in range(48):
				await step(func(): p._physics_process(1.0 / 60.0))
				ControllerHandler.input_primary_just_pressed = false
				var remaining := 0
				for brick in row:
					if is_instance_valid(brick) and brick.visible:
						remaining += 1
				var pos := p.body.global_position
				f.store_line(
					(
						"%d,%d,%.6f,%.6f,%.6f,%.6f,%d"
						% [
							k,
							tick + 1,
							pos.x,
							pos.y,
							p.body.velocity.x,
							p.body.velocity.y,
							remaining
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
