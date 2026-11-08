extends Node


func box(parent: Node, at: Vector2) -> void:
	var rect := ColorRect.new()
	rect.position = at
	rect.size = Vector2(8, 8)
	rect.color = Color.RED
	parent.add_child(rect)


func frames() -> void:
	for index in range(3):
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func check(
	level: BaseLevel, composer: SharedShadowComposer, label: String, game: Node = null
) -> void:
	level.active_area.background_color = Color(0.3, 0.3, 0.3, 1)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.hide()
	level.active_area.get_node("Layouts/GroundLayout").hide()
	level.active_area.get_node("Layouts/EntityLayout").hide()
	var decorations := level.active_area.get_node("Layouts/DecorationLayout") as TileMapLayer
	decorations.clear()
	for child in level.world_objects.get_children():
		if child is CanvasItem:
			child.hide()
	box(decorations, Vector2(100, 60))
	box(level.world_objects, Vector2(60, 60))
	var camera := level.active_area.get_node("Camera2D") as LevelCamera
	camera.follow_enabled = false
	camera.position = Vector2(128, 120)
	camera.force_update_scroll()
	for style_name in ["soft", "crisp", "outer_blur", "none", "soft"]:
		var style := (
			load("res://assets/shadows/" + style_name + ".tres") as ShadowStyle
			if style_name != "none"
			else null
		)
		if game != null:
			game.shadow_style = style
		else:
			composer.set_shadow_style(style)
		composer.sync_rendering()
		assert(composer._routed_decorations == decorations)
		assert(decorations.get_parent() == level.active_area.get_node("Layouts"))
		assert(level.material == null)
		assert((composer.material == null) == (style_name == "none"))
		assert(
			(
				(composer._source.render_target_update_mode == SubViewport.UPDATE_DISABLED)
				== (style_name == "none")
			)
		)
		if style_name == "crisp":
			assert(composer._horizontal.render_target_update_mode == SubViewport.UPDATE_DISABLED)
		if style_name == "outer_blur":
			assert(composer._level_material.get_shader_parameter("shadow_offset") == Vector2.ZERO)
		await frames()
		if DisplayServer.get_name() != "headless":
			var shot := get_viewport().get_texture().get_image()
			assert(sample(shot, 63, 63).is_equal_approx(Color.RED), "Foreground must stay sharp.")
			assert(
				sample(shot, 103, 63).is_equal_approx(Color.RED), "Decorations must remain visible."
			)
			var background := sample(shot, 140, 100)
			assert(
				sample(shot, 109, 69).is_equal_approx(background),
				"Decorations must not cast shadows."
			)
			if style_name == "crisp":
				assert(sample(shot, 69, 69).r < background.r - 0.05)
			elif style_name == "none":
				assert(sample(shot, 69, 69).is_equal_approx(background))
			elif style_name == "outer_blur":
				assert(minf(sample(shot, 59, 63).r, sample(shot, 68, 63).r) < background.r - 0.005)

			assert(
				shot.save_png("res://.godot/validation/" + label + "-" + style_name + ".png") == OK
			)


func sample(shot: Image, x: int, y: int) -> Color:
	var scale := minf(shot.get_width() / 256.0, shot.get_height() / 240.0)
	var offset := (Vector2(shot.get_size()) - Vector2(256, 240) * scale) / 2
	var at := offset + (Vector2(x, y) + Vector2(0.5, 0.5)) * scale
	return shot.get_pixel(int(at.x), int(at.y))


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("window_render_test: SKIPPED (rendered window required)")
		get_tree().quit()
		return
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	game.start_with_title = false
	game.transitions_enabled = false
	game.initial_level = load("res://scenes/levels/test_level.tscn")
	add_child(game)
	for dimensions in [Vector2i(768, 720), Vector2i(1024, 960), Vector2i(1000, 700)]:
		get_window().size = dimensions
		await frames()
		await frames()
		var image := get_viewport().get_texture().get_image()
		var scale := minf(dimensions.x / 256.0, dimensions.y / 240.0)
		assert(
			(
				absi(image.get_width() - int(256 * scale)) <= 1
				and absi(image.get_height() - int(240 * scale)) <= 1
			),
			"Aspect-preserving render must fill fitted window region"
		)
		await check(
			GameHandler.current_level,
			game.get_node("SharedShadow"),
			"window-%sx%s" % [dimensions.x, dimensions.y],
			game
		)
	game.free()
	await frames()
	print("window_render_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
