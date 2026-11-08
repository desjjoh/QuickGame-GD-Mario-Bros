extends Node


func _ready() -> void:
	var level := preload("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	var layout := level.get_node("Areas/MainArea/Layouts/EnemyLayout") as TileMapLayer
	layout.clear()
	level.entity_layout.clear()
	for x in range(4, 15):
		layout.set_cell(Vector2i(x, 12), 0, Vector2i.ZERO)
	add_one_up_placement(level, Vector2i(12, 12))

	var camera := level.get_node("Areas/MainArea/Camera2D") as LevelCamera
	var original_position := camera.position
	camera.position.x = -1000
	add_child(level)
	var area := level.active_area
	for placement in level.world_objects.get_children():
		assert(placement.get_child_count() == 1, "Only the placement's state machine should exist.")

	camera.position = original_position
	area.update_camera_activity()
	var active: Array[BaseEnemy] = []
	var skipped: EntitySpawner
	for placement in level.world_objects.get_children():
		if not placement.name.begins_with("goomba_spawner"):
			continue
		var enemy := placement.get_node_or_null("Goomba") as BaseEnemy
		if enemy == null:
			assert(skipped == null)
			skipped = placement
		else:
			active.append(enemy)
	assert(active.size() == 10 and skipped != null)
	assert(not level.has_spawn_capacity(&"enemy"))
	var power_up := level.world_objects.get_node("one_up_spawner_12_12/OneUpMushroom")
	assert(power_up is PowerUp and not level.has_spawn_capacity(&"power_up"))

	var legacy := (
		preload("res://scenes/entities/spawners/enemy_spawner.tscn").instantiate() as EnemySpawner
	)
	legacy.enemy_scene = preload("res://scenes/entities/enemies/goomba/goomba.tscn")
	legacy.position = Vector2(180, 192)
	level.world_objects.add_child(legacy)
	area.update_camera_activity()
	assert(legacy.actor == null)

	var removed := active[0]
	var cleanup := area.get_activity_region(true)
	removed.body.global_position.y = cleanup.end.y + 1.0
	area.update_camera_activity()
	assert(not removed.is_queued_for_deletion())
	removed.body.global_position.y = cleanup.end.y + 20.0
	area.update_camera_activity()
	assert(removed.is_queued_for_deletion())
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not is_instance_valid(removed))
	assert(level.has_spawn_capacity(&"enemy"))
	assert(not level.has_spawn_capacity(&"power_up"))
	area.update_camera_activity()
	assert(skipped.get_node_or_null("Goomba") == null and legacy.actor == null)

	camera.position.x = -1000
	area.update_camera_activity()
	await get_tree().process_frame
	await get_tree().process_frame
	camera.position = original_position
	area.update_camera_activity()
	assert(skipped.get_node_or_null("Goomba") == null and legacy.actor == null)
	level.queue_free()
	await get_tree().process_frame
	await _test_goomba_contact()
	await _test_stage_placements()
	await _test_enemy_hits()
	print("PASS: enemy limits, cleanup, 16-pixel placements, stomp, side damage and block hits.")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func _test_goomba_contact() -> void:
	var level := preload("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	add_child(level)
	var scene := preload("res://scenes/entities/enemies/goomba/goomba.tscn")
	var left := scene.instantiate() as BaseEnemy
	var right := scene.instantiate() as BaseEnemy
	left.position = Vector2(92, 192)
	right.position = Vector2(132, 192)
	left.get_node("StateMachine/Walking").initial_direction = 1
	level.world_objects.add_child(left)
	for tick in range(9):
		await get_tree().physics_frame
	level.world_objects.add_child(right)
	assert(left.sprite.frame == right.sprite.frame)
	for tick in range(5):
		await get_tree().physics_frame
	assert(left.body.velocity.x == 30.0 and right.body.velocity.x == -30.0)
	for tick in range(40):
		await get_tree().physics_frame
		assert(left.sprite.frame == right.sprite.frame)
	assert(left.body.velocity.x == -30.0 and right.body.velocity.x == 30.0)
	assert(left.body.is_on_floor() and right.body.is_on_floor())
	assert(left.body.global_position.x < right.body.global_position.x)
	left.body.global_position = Vector2(150, 200)
	right.body.global_position = Vector2(128, 200)
	assert(left.receive_hit(EntityHit.new(null, &"stomp", Vector2.DOWN)))
	for tick in range(25):
		await get_tree().physics_frame
	assert(left.state_machine.current_state.name == &"Squashed")
	assert(right.body.velocity.x == -30.0)
	level.queue_free()
	await get_tree().process_frame


func _test_stage_placements() -> void:
	var level := preload("res://scenes/levels/worlds/world 1/1-1.tscn").instantiate() as BaseLevel
	var layout := level.get_node("Areas/MainArea/Layouts/EnemyLayout") as TileMapLayer
	assert(layout.tile_set.tile_size == Vector2i(16, 16))
	# The authored stage is editable. Keep this test's placement independent.
	layout.clear()
	layout.set_cell(Vector2i(51, 12), 1, Vector2i.ZERO)
	for source_id in [0, 1]:
		var atlas := layout.tile_set.get_source(source_id) as TileSetAtlasSource
		assert(atlas.get_tile_data(Vector2i.ZERO, 0).texture_origin == Vector2i.ZERO)
	add_child(level)
	await get_tree().physics_frame
	var goomba := preload("res://scenes/entities/enemies/goomba/goomba.tscn").instantiate()
	var collider := goomba.get_node("Body/CollisionShape2D") as CollisionShape2D
	var body_offset := (collider.get_parent() as Node2D).position + collider.position
	var shape := collider.shape
	goomba.free()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 1
	query.exclude = [level.player.body.get_rid()]
	var space := level.get_world_2d().direct_space_state
	for placement in level.world_objects.get_children():
		if not placement is EntitySpawner or placement.spawn_category != &"enemy":
			continue
		for offset in placement.actor_offsets:
			var origin: Vector2 = placement.global_position + offset
			# Ground contact is intentional; reject penetration, not a touching floor.
			query.transform = Transform2D(0, origin + body_offset - Vector2(0, 0.01))
			assert(
				space.intersect_shape(query).is_empty(), "Enemy starts inside terrain: %s" % origin
			)
			var feet := origin + body_offset + Vector2(0, shape.get_rect().end.y)
			var floor_query := PhysicsRayQueryParameters2D.create(
				feet - Vector2(0, 0.1), feet + Vector2(0, 0.1), 1, [level.player.body.get_rid()]
			)
			var floor_hit := space.intersect_ray(floor_query)
			assert(not floor_hit.is_empty(), "No surface below enemy: %s" % origin)
			assert(is_equal_approx(floor_hit.position.y - feet.y, 0.0))
	var pair := level.world_objects.get_node("goomba_pair_spawner_51_12") as EntitySpawner
	var camera := level.active_area.get_node("Camera2D") as LevelCamera
	camera.follow_enabled = false
	camera.position.x += pair.global_position.x - level.active_area.get_enemy_group_origin_x()
	level.active_area.update_camera_activity()
	var wake := level.active_area.get_enemy_spawn_region()
	var actors: Array[BaseEnemy] = []
	for child in pair.get_children():
		if child is BaseEnemy:
			actors.append(child)
	assert(actors.size() == 2)
	assert(actors[1].global_position - actors[0].global_position == Vector2(24, 0))
	assert(actors[0].global_position.x == level.active_area.get_enemy_group_origin_x())
	assert(actors[1].global_position.x == actors[0].global_position.x + 24)
	assert(not actors[0].activity_suspended and not actors[1].activity_suspended)
	var first_x := actors[0].body.global_position.x
	for tick in range(5):
		await get_tree().physics_frame
	assert(actors[0].body.global_position.x < first_x)
	assert(
		is_equal_approx(actors[1].body.global_position.x - actors[0].body.global_position.x, 24.0)
	)
	assert(not pair.persist_progress)
	assert(actors[0].receive_hit(EntityHit.new(null, &"fireball", Vector2.RIGHT)))
	assert(actors[0].state_machine.current_state.name == &"KnockedOut")
	var area := level.active_area
	level._unload_area(area)
	assert(not is_instance_valid(pair))
	level._load_area(area)
	pair = level.world_objects.get_node("goomba_pair_spawner_51_12") as EntitySpawner
	pair.update_activity(wake, wake, area.theme)
	assert(pair.get_child_count() == 3)
	level.queue_free()
	await get_tree().process_frame


func _test_enemy_hits() -> void:
	var level := preload("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	level.entity_layout.clear()
	level.entity_layout.set_cell(Vector2i(4, 9), 1, Vector2i.ZERO)
	level.entity_layout.set_cell(Vector2i(6, 9), 1, Vector2i.ZERO)
	# These edge-contact assertions deliberately exercise the Small profile.
	level.player_start_configuration = preload("res://assets/player/forms/small.tres")
	add_child(level)
	var player := level.player
	var scene := preload("res://scenes/entities/enemies/goomba/goomba.tscn")
	var stomped := scene.instantiate() as BaseEnemy
	stomped.position = Vector2(144, 192)
	level.world_objects.add_child(stomped)
	player.body.global_position = Vector2(150, 180)
	player.body.velocity.y = 120
	var score := GameHandler.player_status.score
	var lives := GameHandler.player_status.lives
	for tick in range(15):
		await get_tree().physics_frame
		if stomped.state_machine.current_state.name == &"Squashed":
			break
	assert(stomped.state_machine.current_state.name == &"Squashed")
	assert(stomped.sprite.frame == 2 and player.body.velocity.y < 0.0)
	assert(
		GameHandler.player_status.score == score + 100 and GameHandler.player_status.lives == lives
	)
	assert(not stomped.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))

	var corner := scene.instantiate() as BaseEnemy
	corner.position = Vector2(120, 192)
	corner.get_node("StateMachine/Walking").walk_speed = 0.0
	level.world_objects.add_child(corner)
	player.set_physics_process(false)
	# The terrain boxes overlap here, but the smaller combat boxes do not.
	player.body.global_position = Vector2(117, 204)
	player.body.velocity = Vector2.ZERO
	for tick in range(4):
		await get_tree().physics_frame
	assert(not level.death_in_progress)
	var contact_position := Vector2(119, 204)
	player.body.global_position = contact_position
	player.body.velocity = Vector2(90, 120)
	for tick in range(4):
		await get_tree().physics_frame
	assert(corner.state_machine.current_state.name == &"Squashed")
	assert(player.body.global_position == contact_position)
	assert(player.body.velocity == Vector2(90, -240))
	assert(GameHandler.player_status.score == score + 300)  # Consecutive airborne stomps: 100 + 200.
	player.set_physics_process(true)

	var knocked := scene.instantiate() as BaseEnemy
	knocked.position = Vector2(64, 128)
	level.world_objects.add_child(knocked)
	var mushroom := (
		preload("res://scenes/entities/powerups/one_up_mushroom.tscn").instantiate() as Mushroom
	)
	mushroom.position = Vector2(96, 128)
	level.world_objects.add_child(mushroom)
	for tick in range(3):
		await get_tree().physics_frame
	var block := level.world_objects.get_node("question_block_4_9") as BaseBlock
	assert(block.receive_hit(EntityHit.new(player, &"bonk", Vector2.UP)))
	assert(knocked.state_machine.current_state.name == &"KnockedOut" and knocked.sprite.flip_v)
	var mushroom_block := level.world_objects.get_node("question_block_6_9") as BaseBlock
	assert(mushroom_block.receive_hit(EntityHit.new(player, &"bonk", Vector2.UP)))
	assert(mushroom.body.velocity.y < 0.0)
	assert(mushroom.body.velocity.x == -mushroom.walk_speed)
	var knock_origin := knocked.body.global_position
	for tick in range(4):
		await get_tree().physics_frame
	assert(knocked.body.global_position.x < knock_origin.x)
	assert(knocked.body.global_position.y < knock_origin.y)
	for tick in range(32):
		await get_tree().physics_frame
	assert(is_instance_valid(knocked))
	for tick in range(90):
		await get_tree().physics_frame
		if not is_instance_valid(knocked):
			break
	assert(not is_instance_valid(knocked))

	var hazard := scene.instantiate() as BaseEnemy
	hazard.position = Vector2(180, 192)
	level.world_objects.add_child(hazard)
	player.body.global_position = Vector2(186, 208)
	player.body.velocity = Vector2.ZERO
	for tick in range(6):
		await get_tree().physics_frame
	assert(level.death_in_progress and GameHandler.player_status.lives == lives - 1)
	level.queue_free()
	await get_tree().process_frame


func add_one_up_placement(level: BaseLevel, cell: Vector2i) -> void:
	var placement := preload("res://scenes/entities/spawners/one_up_spawner.tscn").instantiate()
	placement.name = "one_up_spawner_%s_%s" % [cell.x, cell.y]
	placement.position = Vector2(cell * 16)
	level.get_node("Areas/MainArea/WorldObjects").add_child(placement)
