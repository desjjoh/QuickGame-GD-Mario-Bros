extends Node


func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	var koopa_scene := load("res://scenes/entities/enemies/koopa/green_koopa.tscn") as PackedScene
	for theme in ["overworld", "underground", "castle"]:
		var preview := koopa_scene.instantiate() as BaseEnemy
		preview.visual_theme = load("res://assets/themes/%s.tres" % theme)
		add_child(preview)
		assert(
			(
				preview.sprite.texture.resource_path
				== "res://assets/palettes/%s/enemies/koopa.png" % theme
			)
		)
		preview.free()
	for path in [
		"res://assets/tileset/enemy_layout.tres",
		"res://assets/tileset/underground/enemy_layout.tres",
		"res://assets/tileset/castle/enemy_layout.tres"
	]:
		var tiles := load(path) as TileSet
		var marker := tiles.get_source(2) as TileSetAtlasSource
		assert(tiles.tile_size == Vector2i(16, 16))
		assert(marker.texture_region_size == Vector2i(16, 32))
		var expected_theme: String = (
			"overworld"
			if path == "res://assets/tileset/enemy_layout.tres"
			else path.get_base_dir().get_file()
		)
		assert(marker.texture.resource_path.contains("/%s/enemies/koopa.png" % expected_theme))
		assert(marker.get_tile_data(Vector2i.ZERO, 0).texture_origin == Vector2i(0, 8))
		assert(
			(
				marker.get_tile_data(Vector2i.ZERO, 0).get_custom_data("entity_id")
				== "green_koopa_spawner"
			)
		)
	var level := load("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
	level.entity_layout.clear()
	var floor := level.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
	floor.clear()
	for x in range(24):
		floor.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
	for y in range(13):
		floor.set_cell(Vector2i(0, y), 0, Vector2i.ZERO)
	var layout := level.get_node("Areas/MainArea/Layouts/EnemyLayout") as TileMapLayer
	layout.clear()
	layout.set_cell(Vector2i(8, 12), 2, Vector2i.ZERO)
	var camera := level.get_node("Areas/MainArea/Camera2D") as LevelCamera
	var original := camera.position
	camera.position.x = -1000
	add_child(level)
	var spawner := level.world_objects.get_node("green_koopa_spawner_8_12") as EntitySpawner
	assert(spawner.get_node_or_null("GreenKoopa") == null)
	camera.position = original
	level.active_area.update_camera_activity()
	var koopa := spawner.get_node("GreenKoopa") as BaseEnemy
	assert(spawner.spawn_category == &"enemy" and not koopa.persist_progress)
	assert(koopa.position == Vector2.ZERO and spawner.position == Vector2(128, 192))
	var walking := koopa.get_node("StateMachine/Walking")
	assert(walking.walk_speed == 30 and walking.fall_speed_limit == 180)
	assert(is_equal_approx(walking.gravity, 857.8125))
	assert(koopa.body.get_node("CollisionShape2D").shape.size == Vector2(14, 16))
	assert(koopa.get_node("Body/PlayerContact/CollisionShape2D").shape.size == Vector2(12, 12))
	assert(koopa.get_node("Body/PlayerContact").position == Vector2(0, -1))
	assert(koopa.sprite.hframes == 5 and koopa.sprite.position == Vector2(0, -8))
	assert(
		koopa.sprite.position.y + koopa.sprite.get_rect().end.y == 8,
		"Art feet must align with the body's bottom."
	)
	assert(not koopa.sprite.flip_h)
	assert(koopa._can_hurt_player())
	koopa.body.global_position = Vector2(128, 100)
	koopa.body.velocity = Vector2.ZERO
	walking.process_physics(1.0 / 60.0)
	assert(is_equal_approx(koopa.body.global_position.y, 100))
	assert(is_equal_approx(koopa.body.velocity.y, 857.8125 / 60.0))
	assert(koopa.body.velocity.x == -30)
	await ticks(45)
	assert(koopa.body.is_on_floor())
	# A late join samples the same global frame and shares enemy reversal.
	var other := koopa_scene.instantiate() as BaseEnemy
	other.position = Vector2(160, 192)
	level.world_objects.add_child(other)
	assert(other.sprite.frame == koopa.sprite.frame)
	koopa.body.global_position = Vector2(128, 200)
	walking._turn_around()
	assert(koopa.sprite.flip_h)
	await ticks(40)
	assert(koopa.body.velocity.x == -30 and not koopa.sprite.flip_h)
	assert(other.body.velocity.x == 30 and other.sprite.flip_h)
	assert(koopa.sprite.frame == other.sprite.frame)
	# Wall reversal uses the same facing update.
	koopa.body.global_position = Vector2(24, 200)
	await ticks(12)
	assert(koopa.body.velocity.x == 30 and koopa.sprite.flip_h)
	koopa.body.global_position.x = -1000
	level.active_area.update_camera_activity()
	await ticks(2)
	assert(spawner.get_node_or_null("GreenKoopa") == null)
	level.active_area.update_camera_activity()
	assert(spawner.get_node_or_null("GreenKoopa") == null)
	level.queue_free()
	await ticks(2)
	print("koopa_walking_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
