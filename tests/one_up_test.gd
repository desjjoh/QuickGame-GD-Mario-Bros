extends Node


func _ready() -> void:
	for path in [
		"res://assets/tileset/entity_layout.tres",
		"res://assets/tileset/underground/entity_layout.tres",
		"res://assets/tileset/castle/entity_layout.tres"
	]:
		var tiles := load(path) as TileSet
		assert(not tiles.has_source(8), "1-Up is no longer an EntityLayout paint marker.")
	var stage := preload("res://scenes/levels/worlds/world 1/1-1.tscn").instantiate() as BaseLevel
	assert(stage.entity_scenes.has(&"one_up_spawner"))
	stage.free()

	var level := preload("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
	level.player_start_configuration = MarioFormPresentation.SMALL
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	var ground := level.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
	ground.clear()
	for x in range(32):
		ground.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
	for y in range(9, 13):
		ground.set_cell(Vector2i(16, y), 0, Vector2i.ZERO)
	add_one_up_placement(level, Vector2i(8, 12))
	var camera := level.get_node("Areas/MainArea/Camera2D") as LevelCamera
	var original_position := camera.position
	camera.position.x = -1000
	add_child(level)
	var area := level.active_area
	var spawner := level.world_objects.get_node("one_up_spawner_8_12") as EntitySpawner
	assert(spawner.get_node_or_null("OneUpMushroom") == null)

	camera.position = original_position
	area.update_camera_activity()
	area.update_camera_activity()
	var mushroom := spawner.get_node("OneUpMushroom") as Mushroom
	var pickup_shape := mushroom.pickup.get_node("CollisionShape2D") as CollisionShape2D
	assert((pickup_shape.shape as RectangleShape2D).size == Vector2(12, 12))
	assert(mushroom.pickup.position == Vector2(0, -1))
	assert(level.player.body in mushroom.body.get_collision_exceptions())
	assert(
		(
			mushroom.sprite.texture
			== area.theme.resolve_texture(
				load("res://assets/palettes/overworld/misc/green-mushroom.png")
			)
		)
	)
	assert(mushroom.global_position == Vector2(128, 192))
	var spawn_position := mushroom.body.global_position
	mushroom.body.global_position = Vector2(228, 170)
	var reversed := false
	for tick in range(35):
		await get_tree().physics_frame
		reversed = reversed or mushroom.body.velocity.x < 0.0
	assert(reversed and mushroom.body.is_on_floor())
	mushroom.body.global_position = spawn_position
	var previous_lives := GameHandler.player_status.lives
	var voice := SoundHandler.get_node("Square2Sfx") as AudioStreamPlayer
	level.player.body.global_position = mushroom.global_position + Vector2(8, 16)
	for tick in range(10):
		await get_tree().physics_frame

	assert(GameHandler.player_status.lives == previous_lives + 1)
	assert(voice.playing and voice.stream == SoundHandler.get_sound(&"extra_life"))
	assert(not is_instance_valid(mushroom))
	assert(level.has_spawn_capacity(&"power_up"))
	var popup := spawner.get_node("ScorePopup") as Sprite2D
	assert(popup.visible and popup.region_rect == Rect2(16, 40, 16, 8))
	assert(not popup.is_physics_interpolated())
	var popup_y := popup.global_position.y
	assert(spawner.capture_area_state() == {"consumed": true})
	area.update_camera_activity()
	assert(spawner.get_node_or_null("OneUpMushroom") == null)
	for tick in range(6):
		await get_tree().physics_frame
	assert(popup.global_position.y < popup_y)
	for tick in range(48):
		await get_tree().physics_frame
	assert(not is_instance_valid(popup))
	level.queue_free()
	await get_tree().process_frame

	level = preload("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
	add_one_up_placement(level, Vector2i(8, 12))
	add_one_up_placement(level, Vector2i(10, 12))
	add_child(level)
	area = level.active_area
	spawner = level.world_objects.get_node("one_up_spawner_8_12") as EntitySpawner
	var waiting := level.world_objects.get_node("one_up_spawner_10_12") as EntitySpawner
	if spawner.get_node_or_null("OneUpMushroom") == null:
		var first := waiting
		waiting = spawner
		spawner = first
	mushroom = spawner.get_node("OneUpMushroom") as Mushroom
	assert(waiting.get_node_or_null("OneUpMushroom") == null)
	assert(not level.has_spawn_capacity(&"power_up"))
	assert(level.has_spawn_capacity(&"unlimited_test_category"))
	var cleanup_region := area.get_activity_region(true)
	mushroom.body.global_position.x = cleanup_region.end.x + 1.0
	area.update_camera_activity()
	assert(not mushroom.is_queued_for_deletion())
	mushroom.body.global_position.x = cleanup_region.end.x + 20.0
	previous_lives = GameHandler.player_status.lives
	area.update_camera_activity()
	assert(waiting.get_node_or_null("OneUpMushroom") == null)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not is_instance_valid(mushroom))
	assert(GameHandler.player_status.lives == previous_lives)
	assert(spawner.capture_area_state().is_empty())
	area.update_camera_activity()
	assert(level.has_spawn_capacity(&"power_up"))
	assert(waiting.get_node_or_null("OneUpMushroom") == null)
	camera = area.get_node("Camera2D") as LevelCamera
	camera.position.x = -1000
	area.update_camera_activity()
	camera.position = original_position
	area.update_camera_activity()
	assert(waiting.get_node_or_null("OneUpMushroom") == null)
	assert(spawner.get_node_or_null("OneUpMushroom") == null)
	level.queue_free()
	await get_tree().process_frame
	print(
		"PASS: 1-Up activation, movement, collection, popup, cleanup, and one live power-up per level."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func add_one_up_placement(level: BaseLevel, cell: Vector2i) -> void:
	var placement := preload("res://scenes/entities/spawners/one_up_spawner.tscn").instantiate()
	placement.name = "one_up_spawner_%s_%s" % [cell.x, cell.y]
	placement.position = Vector2(cell * 16)
	level.get_node("Areas/MainArea/WorldObjects").add_child(placement)
