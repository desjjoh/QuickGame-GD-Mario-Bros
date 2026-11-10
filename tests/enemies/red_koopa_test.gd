extends Node

const STAGE := preload("res://scenes/levels/worlds/world 1/1-2.tscn")
const RED_ART := preload("res://assets/enemies/red-koopa.png")
const STEP := 1.0 / 60.0
const SPAWN_CELL := Vector2i(146, 12)


func _ready() -> void:
	for theme_name in ["overworld", "underground", "castle"]:
		var theme := load("res://assets/themes/%s.tres" % theme_name) as AreaTheme
		var marker := theme.enemy_markers.get_source(5) as TileSetAtlasSource
		assert(marker.texture == RED_ART and theme.resolve_texture(RED_ART) == RED_ART)
		assert(
			(
				marker.get_tile_data(Vector2i.ZERO, 0).get_custom_data("entity_id")
				== "red_koopa_spawner"
			)
		)
		assert(marker.get_tile_data(Vector2i.ZERO, 0).texture_origin == Vector2i(0, 8))

	var level := STAGE.instantiate() as BaseLevel
	level.opening_presentation = null
	var area := level.get_node("Areas/MainArea") as BaseLevelArea
	var layout := area.get_node("Layouts/EnemyLayout") as TileMapLayer
	assert(layout.get_cell_source_id(SPAWN_CELL) == 5)
	layout.clear()
	layout.set_cell(SPAWN_CELL, 5, Vector2i.ZERO)
	add_child(level)
	level.player.set_physics_process(false)
	area.set_physics_process(false)
	var camera := area.get_node("Camera2D") as LevelCamera
	camera.follow_enabled = false
	camera.position.x = 2032.0 + 128.0
	var spawner := level.world_objects.get_node("red_koopa_spawner_146_12") as EntitySpawner
	area.update_camera_activity()
	assert(spawner.get_node_or_null("RedKoopa") == null)
	camera.position.x += 1.0
	area.update_camera_activity()
	var red := spawner.get_node("RedKoopa") as BaseEnemy
	assert(area.to_local(red.body.global_position) == Vector2(2344, 200))
	assert(level.spawn_registry.get_slot(&"enemy", red) == 0)
	assert(red.sprite.texture == RED_ART)
	red.set_physics_process(false)
	level.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Original 1-2 ledge traces, sampled after the movement update.
	check_ledge(
		red, area, 234, 1, [234, 235, 235, 236, 236, 237, 237, 238, 238, 239, 239, 240, 239, 239]
	)
	check_ledge(
		red,
		area,
		2182,
		-1,
		[2181, 2181, 2180, 2180, 2179, 2179, 2178, 2178, 2177, 2177, 2176, 2176, 2175, 2176]
	)

	var walking = red.get_node("StateMachine/Walking")
	var idle = red.get_node("StateMachine/ShellIdle")
	red.body.global_position = area.to_global(Vector2(2176, 136))
	assert(red.receive_hit(EntityHit.new(level.player, &"stomp", Vector2.DOWN)))
	assert(red.state_machine.current_state == idle and red.sprite.vframes == 2)
	idle.wake_ticks_remaining = 1
	var clock := GameHandler.animation_clock
	var saved_tick := clock.tick_count
	clock.tick_count = 1
	red._physics_process(STEP)
	clock.tick_count = saved_tick
	assert(red.state_machine.current_state == walking and red.sprite.vframes == 1)
	assert(red.sprite.texture == RED_ART and walking._direction == -1)
	red._physics_process(STEP)
	assert(area.to_local(red.body.global_position).is_equal_approx(Vector2(2175.5, 136)))
	red._physics_process(STEP)
	assert(area.to_local(red.body.global_position).is_equal_approx(Vector2(2176, 136)))
	assert(walking._direction == 1)

	red.body.global_position = area.to_global(Vector2(2182, 136))
	level.player.body.global_position = area.to_global(Vector2(2240, 200))
	assert(red.receive_hit(EntityHit.new(level.player, &"stomp", Vector2.DOWN)))
	assert(red.receive_hit(EntityHit.new(level.player, &"kick", Vector2.ZERO)))
	for expected_x: int in [2179, 2176, 2173, 2171, 2170, 2168, 2167, 2165]:
		red._physics_process(STEP)
		assert(floori(area.to_local(red.body.global_position).x) == expected_x)
	assert(area.to_local(red.body.global_position).y > 136 and red.is_moving_shell())
	level.queue_free()
	await get_tree().process_frame
	print("red_koopa_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func check_ledge(
	red: BaseEnemy, area: BaseLevelArea, x: int, direction: int, centers: Array
) -> void:
	var walking = red.state_machine.current_state
	if walking._direction != direction:
		walking._turn_around()
	red.body.global_position = area.to_global(Vector2(x, 136))
	for center: int in centers:
		red._physics_process(STEP)
		var local := area.to_local(red.body.global_position)
		assert(floori(local.x) == center, "Expected X%s, got %s" % [center, local.x])
		assert(is_equal_approx(local.y, 136.0) and red.body.velocity.y == 0.0)
	assert(walking._direction == -direction and red.sprite.flip_h == (direction < 0))
