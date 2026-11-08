extends Node


func ticks(count: int) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	await check_actor(0, "goomba_spawner_8_12", "Goomba")
	await check_actor(2, "green_koopa_spawner_8_12", "GreenKoopa")
	print("nested_entity_activity_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func check_actor(source: int, marker: String, actor_name: String) -> void:
	var level := load("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
	level.entity_layout.clear()
	var layout := level.get_node("Areas/MainArea/Layouts/EnemyLayout") as TileMapLayer
	layout.clear()
	layout.set_cell(Vector2i(8, 12), source, Vector2i.ZERO)
	add_child(level)
	level.player.set_physics_process(false)
	level.player.body.global_position = Vector2(24, 64)
	var area := level.active_area
	var camera := area.get_node("Camera2D") as LevelCamera
	camera.follow_enabled = false
	var spawner := level.world_objects.get_node(marker) as EntitySpawner
	var enemy := spawner.get_node(actor_name) as BaseEnemy
	var original := camera.position
	camera.position.x = 600
	enemy.body.global_position = Vector2(600, 120)
	area.update_camera_activity()
	assert(spawner.activity_suspended and not enemy.activity_suspended)
	assert(enemy.is_processing() and enemy.is_physics_processing())
	var sync := (
		enemy.find_children("*", "SynchronizedAnimation", true, false)[0] as SynchronizedAnimation
	)
	assert(sync.enabled and not sync.activity_suspended)
	# Refreshing the parent's geometry must not absorb the moving actor's bounds.
	spawner.refresh_activity_geometry()
	assert(not spawner.get_activity_rect().intersects(enemy.get_activity_rect()))
	# Parent wake must not undo an independently suspended child's processing.
	enemy.set_gameplay_suspended(true)
	camera.position = original
	area.update_camera_activity()
	assert(not spawner.activity_suspended and not enemy.is_physics_processing())
	enemy.set_gameplay_suspended(false)
	camera.position.x = 600
	area.update_camera_activity()
	assert(spawner.activity_suspended and enemy.is_physics_processing())
	if source == 2:
		assert(enemy.receive_hit(EntityHit.new(level.player, &"stomp", Vector2.DOWN)))
		assert(enemy.receive_hit(EntityHit.new(level.player, &"kick", Vector2.ZERO)))
		assert(enemy.is_moving_shell())
	var position := enemy.body.global_position
	var reference: WeakRef = weakref(enemy)
	await ticks(10)
	assert(is_instance_valid(enemy) and enemy.body.global_position != position)
	assert(enemy.is_physics_processing())
	# Let real walking/rolling/falling carry the actor through the cleanup edge.
	for index in range(240):
		if reference.get_ref() == null:
			break
		await ticks(1)
	assert(reference.get_ref() == null)
	assert(level.has_spawn_capacity(&"enemy"))
	assert(level.spawn_registry._live_spawns[&"enemy"].is_empty())
	camera.position = original
	area.update_camera_activity()
	assert(spawner.get_node_or_null(actor_name) == null)
	level.queue_free()
	await ticks(2)
