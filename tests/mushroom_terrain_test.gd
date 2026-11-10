extends Node

const LEVEL := preload("res://tests/fixtures/sandbox_level.tscn")
const MUSHROOMS := [
	preload("res://scenes/entities/powerups/super_mushroom.tscn"),
	preload("res://scenes/entities/powerups/one_up_mushroom.tscn")
]
const STEP := 1.0 / 60.0
signal tick_finished


func _physics_process(_delta: float) -> void:
	tick_finished.emit()


func _ready() -> void:
	process_physics_priority = 200
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var level := LEVEL.instantiate() as BaseLevel
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	var area := level.get_node("Areas/MainArea") as BaseLevelArea
	area.position = Vector2(160, 237)
	area.theme = preload("res://assets/themes/underground.tres")
	var ground := area.get_node("Layouts/GroundLayout") as TileMapLayer
	ground.tile_set = area.theme.terrain
	ground.clear()
	for column in range(24):
		ground.set_cell(Vector2i(column, 13), 0, Vector2i.ZERO)
	ground.set_cell(Vector2i(17, 12), 0, Vector2i(0, 1))
	# Same question-block ledge and first step as 1-2.
	for column in range(10, 15):
		level.entity_layout.set_cell(Vector2i(column, 9), 1, Vector2i.ZERO)
	level.entity_layout.set_cell(Vector2i(8, 8), 0, Vector2i.ZERO)
	canvas.add_child(level)
	level.set_physics_process(false)
	area.set_physics_process(false)
	level.player.set_physics_process(false)
	level.player.body.global_position = area.to_global(Vector2(136, 208))
	await get_tree().process_frame
	await tick_finished
	await tick_finished
	for scene in MUSHROOMS:
		_check_ledge(level, scene)
		_check_walls(level, scene)
	for column in range(10, 15):
		level.world_objects.get_node("question_block_%s_9" % column).free()
	await tick_finished
	for scene in MUSHROOMS:
		await _check_bump(level, scene)
	var mario := level.player as Mario
	mario.form_controller.configure(mario, mario.super_form)
	mario.body.global_position = area.to_global(Vector2(168, 208))
	await tick_finished
	for scene in MUSHROOMS:
		await _check_player_contact(level, scene)
	canvas.free()
	print(
		"PASS: Both mushrooms use center support, turn at walls, land after a bump, and pass through Mario for pickup."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func _spawn(level: BaseLevel, scene: PackedScene, top_left: Vector2, emerging := false) -> Mushroom:
	var mushroom := scene.instantiate() as Mushroom
	mushroom.position = top_left
	if emerging:
		mushroom.begin_emergence()
	level.world_objects.add_child(mushroom)
	mushroom.set_activity_suspended(false)
	mushroom.set_physics_process(false)
	return mushroom


func _sprite_origin(level: BaseLevel, mushroom: Mushroom) -> Vector2:
	return level.active_area.to_local(mushroom.body.global_position) - Vector2(8, 8)


func _check_ledge(level: BaseLevel, scene: PackedScene) -> void:
	var mushroom := _spawn(level, scene, Vector2(160, 144), true)
	for tick in range(1, 65):
		mushroom._physics_process(STEP)
		if tick >= 59:
			var sprite := mushroom.sprite
			var sprite_top := (
				level.active_area.to_local(sprite.to_global(sprite.get_rect().position)).y
			)
			assert(sprite_top == (130.0 if tick == 59 else (129.0 if tick < 64 else 128.0)))
	assert(_sprite_origin(level, mushroom) == Vector2(160, 127))
	for tick in range(71):
		mushroom._advance_available(STEP)
	assert(_sprite_origin(level, mushroom) == Vector2(231, 128) and not mushroom._falling)
	assert(mushroom._vertical.position_fraction == 110)
	mushroom._advance_available(STEP)
	assert(_sprite_origin(level, mushroom) == Vector2(232, 128) and mushroom._falling)
	for tick in range(24):
		mushroom._advance_available(STEP)
		assert(mushroom.body.velocity.y < 210.0)
	assert(
		_sprite_origin(level, mushroom).x == 256.0 and mushroom._direction == -1.0,
		"Ledge turn at %s heading %s" % [_sprite_origin(level, mushroom), mushroom._direction]
	)
	for tick in range(3):
		mushroom._advance_available(STEP)
	assert(_sprite_origin(level, mushroom) == Vector2(253, 192) and not mushroom._falling)
	mushroom.free()


func _check_walls(level: BaseLevel, scene: PackedScene) -> void:
	for sample in [[255.0, 1.0, 256.0], [288.0, -1.0, 287.0]]:
		var mushroom := _spawn(level, scene, Vector2(sample[0], 192))
		mushroom._direction = sample[1]
		mushroom._advance_available(STEP)
		assert(_sprite_origin(level, mushroom) == Vector2(sample[2], 192))
		assert(
			mushroom._direction == -sample[1],
			"Wall turn at %s heading %s" % [_sprite_origin(level, mushroom), mushroom._direction]
		)
		mushroom.free()


func _check_bump(level: BaseLevel, scene: PackedScene) -> void:
	var mushroom := _spawn(level, scene, Vector2(130, 112))
	var block := level.world_objects.get_node("brick_8_8") as BaseBlock
	assert(block.receive_hit(EntityHit.new(level.player, &"bonk", Vector2.UP)))
	assert(_sprite_origin(level, mushroom) == Vector2(130, 110))
	await tick_finished
	mushroom._advance_available(STEP)
	assert(_sprite_origin(level, mushroom) == Vector2(131, 110))
	mushroom._advance_available(STEP)
	assert(_sprite_origin(level, mushroom) == Vector2(132, 107))
	var landing_tick := -1
	for tick in range(3, 73):
		mushroom._advance_available(STEP)
		if not mushroom._falling:
			landing_tick = tick
			break
	assert(landing_tick > 0 and _sprite_origin(level, mushroom).y == 192.0)
	assert(landing_tick == 53 and _sprite_origin(level, mushroom).x == 183.0)
	mushroom.free()
	while block.bounce.is_running():
		await tick_finished


func _check_player_contact(level: BaseLevel, scene: PackedScene) -> void:
	var mushroom := _spawn(level, scene, Vector2(145, 192))
	# The leading probe reaches Mario's terrain body before the pickup boxes meet.
	mushroom._advance_available(STEP)
	assert(mushroom.body.velocity.x > 0.0, "Mario must not turn the mushroom like a wall.")
	mushroom.set_physics_process(true)
	for tick in range(8):
		await tick_finished
		if not is_instance_valid(mushroom):
			return
	assert(mushroom.is_queued_for_deletion(), "The approaching mushroom should be collected.")
