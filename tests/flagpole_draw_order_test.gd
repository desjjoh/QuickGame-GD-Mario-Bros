extends Node


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("PASS: rendered flag draw-order check skipped in headless mode.")
		await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
		return
	get_window().unfocusable = true
	var game = load("res://tests/fixtures/silent_game.tscn").instantiate()
	add_child(game)
	var level = GameHandler.current_level
	level.ending_presentation.flag_sound = null
	level.ending_presentation.music = null
	var player = level.player
	var pole = level.active_area.get_node("WorldObjects/flagpole_196_2")
	var composer = game.get_node("SharedShadow")
	# Isolated overlap fixture; no project textures or palette resources are edited.
	var backing := ColorRect.new()
	backing.position = Vector2(pole.climb_top.global_position.x - 24, 40)
	backing.size = Vector2(48, 150)
	backing.color = Color.WHITE
	level.add_child(backing)
	player.body.global_position = Vector2(pole.climb_top.global_position.x - 7, 100)
	var camera = get_viewport().get_camera_2d()
	camera.snap_to_arrival(player.body)
	for frame in range(5):
		await get_tree().physics_frame
	player.set_gameplay_suspended(true)
	level.ending_presentation.set_physics_process(false)
	player.body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	player.animation_player.pause()
	for frame in range(3):
		await RenderingServer.frame_post_draw
	assert(level.ending_in_progress)
	assert(not composer._players_behind_world, "Flag must never request pipe ordering.")
	var source: Image = composer._source.get_texture().get_image()
	var sprite: Sprite2D = player.sprite
	var texture := sprite.texture.get_image()
	var base: Vector2 = get_viewport().canvas_transform * sprite.global_position
	base += Vector2.ONE * composer.SHADOW_PADDING - Vector2(8, 8)
	var visible := 0
	var expected := 0
	# Rasterization rounds fractional camera positions; accept either adjacent pixel.
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var matches := 0
			expected = 0
			for y in range(16):
				for x in range(16):
					var color := texture.get_pixel(15 - x if sprite.flip_h else x, y)
					if color.a < 0.99:
						continue
					expected += 1
					var point := Vector2i(base.floor()) + Vector2i(x + dx, y + dy)
					if source.get_pixelv(point).is_equal_approx(color):
						matches += 1
			visible = maxi(visible, matches)
	print(
		(
			"Flag sprite visible pixels: %s/%s; pipe route: %s"
			% [visible, expected, composer._players_behind_world]
		)
	)
	assert(visible == expected, "Flag contact must keep Mario in front of world objects.")
	game.free()
	await get_tree().process_frame
	print("PASS: rendered flag contact preserves Mario foreground ordering.")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
