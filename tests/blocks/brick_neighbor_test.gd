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
	var brick_scene := load("res://scenes/entities/blocks/brick/brick_block.tscn") as PackedScene
	var block := brick_scene.instantiate() as BaseBlock
	block.position = Vector2(128, 128)
	level.world_objects.add_child(block)
	await get_tree().physics_frame
	await get_tree().process_frame
	var golden: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/brick_full_jump_reference.json")
	)
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
				var brick := brick_scene.instantiate() as BaseBlock
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
			var hit_step := -1
			var hit_y := 0.0
			var hit_x_speed := 0.0
			for tick in range(48):
				await step(func(): p._physics_process(1.0 / 60.0))
				ControllerHandler.input_primary_just_pressed = false
				var remaining := 0
				for brick in row:
					if is_instance_valid(brick) and brick.visible:
						remaining += 1
				var pos := p.body.global_position
				var expected: Dictionary = golden[str(k)]
				if hit_step < 0 and remaining < 3:
					hit_step = tick + 1
					hit_y = pos.y
					hit_x_speed = p.body.velocity.x
					assert(
						hit_step == int(expected.hit_step),
						(
							"Break frame case %s actual %s expected %s"
							% [k, hit_step, expected.hit_step]
						)
					)
				if hit_step > 0:
					var relative := tick + 1 - hit_step
					if relative < 16:
						assert(remaining == 2, "Gate must prevent a second brick reaction")
					assert(
						p.bonk_action.reaction_ticks_remaining == maxi(0, 16 - relative),
						"Gate must expire at tick 16"
					)
					if relative < 3:
						# These jumps enter an intact neighbor from the side.
						# Preserve the first rise, then descend without a second hit.
						if relative > 0 and k in [3, 5, 19]:
							assert(p.body.velocity.y > 0.0)
							if relative == 1:
								assert(pos.y < hit_y)
							continue
						var target: Dictionary = expected.contact[relative]
						assert(
							pos.y == float(target.feet),
							(
								"Exact full-jump post-break Y: case %s tick %s actual %s expected %s"
								% [k, relative, pos.y, target.feet]
							)
						)
						assert(
							floori(p.body.velocity.y / 60.0) == int(target.vy),
							"Exact vertical integer speed: case %s tick %s" % [k, relative]
						)
						if absf(float(target.vx)) > 100:
							assert(
								p.body.velocity.x * direction > 100,
								"Reference keeps horizontal travel"
							)
						else:
							assert(
								absf(p.body.velocity.x) < 10,
								"Reference side contact stops horizontal travel"
							)
			# Case 1 enters the brick above its underside. The NES capture
			# records a break here, but our underside-only rule rejects it.
			var expected_hit_step := -1 if k == 1 else int(golden[str(k)].hit_step)
			assert(
				hit_step == expected_hit_step,
				(
					"Break/no-break outcome must match case %s got %s expected %s"
					% [k, hit_step, expected_hit_step]
				)
			)
	await check_input_only_jumps(level, brick_scene, row)
	ControllerHandler.input_left = 0
	ControllerHandler.input_right = 0
	ControllerHandler.input_primary = false
	level.free()
	ControllerHandler.set_physics_process(true)
	print("brick_neighbor_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func check_input_only_jumps(level: BaseLevel, scene: PackedScene, row: Array[BaseBlock]) -> void:
	var breaks := 0
	for direction in [1.0, -1.0]:
		for distance in [48.0, 52.0, 56.0, 60.0, 64.0]:
			for brick in row:
				if is_instance_valid(brick):
					brick.free()
			row.clear()
			var cells: Array[Rect2] = []
			for x in [112.0, 128.0, 144.0]:
				var brick := scene.instantiate() as BaseBlock
				brick.position = Vector2(x, 128)
				level.world_objects.add_child(brick)
				row.append(brick)
				cells.append(Rect2(brick.global_position, Vector2(16, 16)))
			await step(func():
				p.bonk_action.reset_reaction_gate()
				p.state_machine.stop(false)
				p.body.global_position = Vector2(136.0 - direction * distance, 208)
				p.body.velocity = Vector2.ZERO
				p.body.move_and_slide()
				p.state_machine.change_state(p.get_node("StateMachine/Idle"))
				ControllerHandler.input_primary = false
				ControllerHandler.input_primary_just_pressed = false
				ControllerHandler.input_secondary = true
				ControllerHandler.input_right = 1 if direction > 0 else 0
				ControllerHandler.input_left = 1 if direction < 0 else 0
			)
			for tick in range(32):
				await step(func(): p._physics_process(1.0 / 60.0))
			assert(p.has_floor_support(), "Input-only jump must start grounded")
			ControllerHandler.input_primary = true
			ControllerHandler.input_primary_just_pressed = true
			var broken := -1
			var break_tick := -1
			var descent_tick := -1
			var broken_depth := 0.0
			var neighbor_depth := 0.0
			for tick in range(48):
				var before_y := p.body.global_position.y
				await step(func(): p._physics_process(1.0 / 60.0))
				ControllerHandler.input_primary_just_pressed = false
				if broken < 0:
					for index in range(row.size()):
						if not is_instance_valid(row[index]) or not row[index].visible:
							broken = index
							break_tick = tick
							break
				if broken < 0:
					continue
				var head := p.get_head_position()
				for index in range(cells.size()):
					var cell := cells[index]
					if not cell.has_point(head):
						continue
					var depth := cell.end.y - head.y
					if index == broken:
						broken_depth = maxf(broken_depth, depth)
					else:
						neighbor_depth = maxf(neighbor_depth, depth)
				if p.body.global_position.y > before_y and descent_tick < 0:
					descent_tick = tick - break_tick
				if descent_tick >= 0 and p.has_floor_support():
					break
			if broken >= 0:
				breaks += 1
				print("Input-only brick jump %s/%s: broken depth=%s, neighbor depth=%s, descent=+%s" %
					[direction, distance, broken_depth, neighbor_depth, descent_tick])
				assert(descent_tick > 0, "Mario must descend after breaking the brick")
				if distance == 56.0:
					assert(descent_tick == 2, "Seam entry must reverse after the first rise")
					assert(broken_depth <= 5.0 and neighbor_depth <= 5.0)
			elif distance == 56.0:
				assert(false, "The 56 px run-up must break a brick in both directions")
	ControllerHandler.input_secondary = false
	assert(breaks > 0, "Input-only jump sweep must exercise a shatter")
