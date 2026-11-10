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
	for cell in range(48):
		terrain.set_cell(Vector2i(cell, 13), 0, Vector2i.ZERO)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(level)
	level.set_physics_process(false)
	level.active_area.set_physics_process(false)
	p = level.player as Mario
	p.set_physics_process(false)
	var cases: Array = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/brick_seam_reference.json")
	)
	for data: Dictionary in cases:
		var blocks: Array[BaseBlock] = []
		for x in [320, 336, 352, 368, 384]:
			var question: bool = x == 336 or x == 368
			var path := (
				"res://scenes/entities/blocks/question/question_block.tscn"
				if question
				else "res://scenes/entities/blocks/brick/brick_block.tscn"
			)
			var block := load(path).instantiate() as BaseBlock
			block.position = Vector2(x, 144)
			level.world_objects.add_child(block)
			block.set_activity_suspended(false)
			if x == 336:
				block.state_machine.change_state(block.get_node("StateMachine/Inactive"))
			blocks.append(block)
		await get_tree().physics_frame
		await step(
			func():
				p.state_machine.stop(false)
				p.bonk_action.reset_reaction_gate()
				p.vertical_movement.reset_fraction()
				p.vertical_movement.position_fraction = int(data.start.yfrac)
				p.body.global_position = Vector2(
					float(data.frames[0].x) + 8, float(data.start.y) + 32
				)
				p.body.velocity = Vector2(
					0, (float(data.start.vy) + float(data.start.vfrac) / 256.0) * 60.0
				)
				p.jump_action.active = true
				p.jump_action.set("_origin_y", 208.0)
				p.jump_action.set("_released", false)
				p.jump_action.set("_rise", 562.5)
				p.jump_action.falling_gravity = 2025
				p.state_machine.change_state(p.get_node("StateMachine/Jump"))
				ControllerHandler.input_primary = true
				ControllerHandler.input_primary_just_pressed = false
				ControllerHandler.input_left = 0
				ControllerHandler.input_right = 0
		)
		for index in range(data.frames.size()):
			var expected: Dictionary = data.frames[index]
			await step(
				func():
					# Replay observed horizontal sample positions, not a second horizontal integrator.
					p.body.global_position.x = float(expected.x) + 8
					p.body.velocity.x = 0
					p._physics_process(1.0 / 60.0)
			)
			var label: String = data.name + " tick " + str(index)
			assert(
				(
					(
						roundf(p.body.global_position.y)
						if p.body.is_on_floor()
						else p.body.global_position.y
					)
					== float(expected.y) + 32
				),
				(
					"Exact seam Y: "
					+ label
					+ " actual "
					+ str(p.body.global_position.y)
					+ " floor "
					+ str(p.body.is_on_floor())
					+ " expected "
					+ str(float(expected.y) + 32)
				)
			)
			assert(
				floori(p.body.velocity.y / 60.0) == int(expected.vy), "Exact seam speed: " + label
			)
			assert(
				p.vertical_movement.speed_fraction == int(expected.vfrac),
				"Exact seam speed fraction: " + label
			)
			assert(
				p.vertical_movement.position_fraction == int(expected.yfrac),
				"Exact seam position fraction: " + label
			)
		for block in blocks:
			if is_instance_valid(block):
				block.free()
	ControllerHandler.input_primary = false
	canvas.free()
	ControllerHandler.set_physics_process(true)
	print("brick_seam_reference_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
