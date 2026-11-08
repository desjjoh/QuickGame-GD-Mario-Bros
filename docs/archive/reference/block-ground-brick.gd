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
	add_child(level)
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
		"res://docs/archive/reference/block-ground-brick.csv", FileAccess.WRITE
	)
	f.store_line("case,step,x,feet,vx,vy,head_inside,upper_inside,probe_colliders")
	var k := 0
	for direction in [1.0, -1.0]:
		for feet in [160.0, 164.0, 168.0, 172.0]:
			block.free()
			block = (
				load("res://scenes/entities/blocks/brick/brick_block.tscn").instantiate()
				as BaseBlock
			)
			block.position = Vector2(128, 128)
			level.world_objects.add_child(block)
			await get_tree().physics_frame
			k += 1
			await step(
				func():
					p.state_machine.stop(false)
					p.body.global_position = Vector2(126 if direction > 0 else 146, feet)
					p.body.velocity = Vector2.ZERO
					p.body.move_and_slide()
					p.jump_action.active = true
					p.jump_action.falling_gravity = 2025
					p.jump_action.set("_released", false)
					p.jump_action.set("_rise", 450.0)
					p.state_machine.change_state(p.get_node("StateMachine/Jump"))
					p.body.velocity = Vector2(150 * direction, -60)
					ControllerHandler.input_right = 1 if direction > 0 else 0
					ControllerHandler.input_left = 1 if direction < 0 else 0
					ControllerHandler.input_primary = true
					ControllerHandler.input_primary_just_pressed = false
			)
			for i in range(24):
				await step(func(): p._physics_process(1.0 / 60.0))
				var pos := p.body.global_position
				var head := pos + Vector2(0, -28)
				var head_inside := Rect2(128, 128, 16, 16).has_point(head)
				var upper_inside := (
					Rect2(128, 128, 16, 16).has_point(pos + Vector2(-6, -24))
					or Rect2(128, 128, 16, 16).has_point(pos + Vector2(5, -24))
				)
				var seen: Array[String] = []
				for offset: Vector2 in [Vector2(0, -28), Vector2(-6, -24), Vector2(5, -24)]:
					var query := PhysicsPointQueryParameters2D.new()
					query.position = pos + offset + Vector2(0.0001, 0.0001)
					query.collision_mask = p.body.collision_mask
					query.exclude = [p.body.get_rid()]
					for hit: Dictionary in p.body.get_world_2d().direct_space_state.intersect_point(
						query
					):
						var label := (hit.collider as Node).get_class()
						if not seen.has(label):
							seen.append(label)
				f.store_line(
					(
						"%s,%s,%.6f,%.6f,%.6f,%.6f,%s,%s,%s"
						% [
							k,
							i + 1,
							pos.x,
							pos.y,
							p.body.velocity.x,
							p.body.velocity.y,
							head_inside,
							upper_inside,
							"|".join(seen)
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
