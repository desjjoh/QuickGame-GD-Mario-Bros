extends Node

const GOOMBA_PAIR_SPAWNER := preload("res://scenes/entities/spawners/goomba_pair_spawner.tscn")


func _ready() -> void:
	var level := load("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	var ground := level.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
	for x in range(49, 55):
		ground.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
	add_child(level)
	var area := level.active_area
	area.set_physics_process(false)
	var camera := area.get_node("Camera2D") as LevelCamera
	camera.follow_enabled = false
	for sample in [[0, 288], [1, 304], [16, 304], [17, 320], [48, 336], [49, 352]]:
		camera.position = Vector2(sample[0] + 128, 120)
		assert(area.get_enemy_spawn_region().end.x - 1 == sample[1])
	camera.position = Vector2(176, 120)  # left 48, last right pixel 303
	var single := (
		load("res://scenes/entities/spawners/goomba_spawner.tscn").instantiate() as EntitySpawner
	)
	single.position = Vector2(352, 184)
	level.world_objects.add_child(single)
	area.update_camera_activity()
	assert(single.get_node_or_null("Goomba") == null)
	camera.position.x += 1
	area.update_camera_activity()
	var enemy := single.get_node("Goomba") as BaseEnemy
	assert(enemy.body.global_position.x - 8 == 352)
	assert(not enemy.activity_suspended)
	# Anchor checks, rather than complete sprite extents; both carry regimes.
	for left in [0.0, 324.0]:
		camera.position.x = left + 128
		var right: float = left + 255
		var limit: float = right + (73 if left >= 73 else 72)
		for sample in [[left - 73, false], [left - 74, true], [limit - 1, false], [limit, true]]:
			enemy.body.global_position.x = sample[0] + 8
			assert(area.enemy_outside_cleanup(enemy) == sample[1])
	# Moving the body away from the stationary placement releases the actual actor.
	enemy.body.global_position.x = 324 - 74 + 8
	area.update_camera_activity()
	assert(enemy.is_queued_for_deletion())
	await get_tree().process_frame
	assert(not is_instance_valid(enemy))
	# Pair reference timing uses the group trigger and creates both members at the right edge.
	camera.position.x = 560 + 128
	var pair := GOOMBA_PAIR_SPAWNER.instantiate() as EntitySpawner
	pair.position = Vector2(816, 192)
	level.world_objects.add_child(pair)
	area.update_camera_activity()
	assert(pair.get_child_count() == 1)
	camera.position.x += 1
	area.update_camera_activity()
	var actors: Array[BaseEnemy] = []
	for child in pair.get_children():
		if child is BaseEnemy:
			actors.append(child)
	assert(actors.size() == 2)
	assert(actors[0].body.global_position.x - 8 == 816)
	assert(actors[1].body.global_position.x - actors[0].body.global_position.x == 24)
	assert(actors[0].body.global_position.y == 200)
	assert(actors[1].body.global_position.y == 200)
	var first := actors[0].body.global_position
	var second := actors[1].body.global_position
	for tick in range(4):
		area.update_camera_activity()
		assert(not actors[0].activity_suspended and not actors[1].activity_suspended)
		await get_tree().physics_frame
		await get_tree().process_frame
	assert(absf(actors[0].body.global_position.y - first.y) < 0.1)
	assert(absf(actors[1].body.global_position.y - second.y) < 0.1)
	assert(actors[0].body.global_position.x < first.x)
	assert(actors[1].body.global_position.x < second.x)
	assert(is_equal_approx(actors[1].body.global_position.x - actors[0].body.global_position.x, 24))
	await check_spawn_beyond_cleanup(level, area)
	# Existing scenery/power-up rectangle defaults remain unchanged.
	assert(area.activation_buffer == 64 and area.deactivation_buffer == 96)
	level.queue_free()
	await get_tree().process_frame
	print("enemy_boundary_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func check_spawn_beyond_cleanup(level: BaseLevel, area: BaseLevelArea) -> void:
	# At this camera position, the pair starts at X816 and cleanup starts at X889.
	var pair := GOOMBA_PAIR_SPAWNER.instantiate() as EntitySpawner
	pair.position = Vector2(816, 192)
	pair.actor_offsets = [Vector2.ZERO, Vector2(80, 0)]
	level.world_objects.add_child(pair)
	area.update_camera_activity()

	var outside: BaseEnemy
	for child in pair.get_children():
		if child is BaseEnemy and area.enemy_outside_cleanup(child):
			outside = child
	assert(is_instance_valid(outside))
	var spawn_x := outside.body.global_position.x - 8.0
	assert(spawn_x == 896.0)
	var slot := level.spawn_registry.get_slot(&"enemy", outside)
	assert(slot >= 0)
	# Walk farther right and let the area's normal physics sweep perform cleanup.
	outside.state_machine.current_state._direction = 1
	var exit_x: Array[float] = []
	outside.tree_exiting.connect(func(): exit_x.append(outside.body.global_position.x - 8.0))
	area.set_physics_process(true)
	await get_tree().physics_frame
	await get_tree().process_frame
	assert(not is_instance_valid(outside))
	assert(exit_x.size() == 1 and exit_x[0] > spawn_x)
	assert(is_instance_valid(pair.get_node_or_null("Goomba")))

	var replacement := preload("res://scenes/entities/enemies/goomba/goomba.tscn").instantiate()
	assert(level.try_claim_spawn_slot(&"enemy", replacement))
	level.world_objects.add_child(replacement)
	assert(level.spawn_registry.get_slot(&"enemy", replacement) == slot)
