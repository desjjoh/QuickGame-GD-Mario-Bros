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
				assert(sample(shot, 59, 64).r < background.r - 0.01)
				assert(absf(sample(shot, 59, 64).r - sample(shot, 68, 64).r) < 0.02)
			assert(
				shot.save_png("res://.godot/validation/" + label + "-" + style_name + ".png") == OK
			)


func sample(shot: Image, x: int, y: int) -> Color:
	# Sample logical pixel centers in the aspect-fitted, native-resolution capture.
	var scale := minf(shot.get_width() / 256.0, shot.get_height() / 240.0)
	var offset := (Vector2(shot.get_size()) - Vector2(256, 240) * scale) / 2
	var at := offset + (Vector2(x, y) + Vector2(0.5, 0.5)) * scale
	return shot.get_pixel(int(at.x), int(at.y))


func _ready() -> void:
	var standalone := load("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
	add_child(standalone)
	assert(standalone.get_node("Systems/ShadowComposer").shadow_style == ShadowStyle.game_default())
	await check(standalone, standalone.get_node("Systems/ShadowComposer"), "standalone-style")
	standalone.free()
	await frames()
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	game.shadow_shader_enabled = true
	game.start_with_title = false
	game.transitions_enabled = false
	game.shadow_style = null
	game.stages.assign([load("res://tests/fixtures/sandbox_level.tscn")])
	add_child(game)
	assert(game.get_node("SharedShadow").material == null)
	await check(GameHandler.current_level, game.get_node("SharedShadow"), "game-style", game)
	game.shadow_style = load("res://assets/shadows/outer_blur.tres")
	assert(GameHandler.load_level(game.stages[0]))
	assert(game.get_node("SharedShadow").shadow_style == game.shadow_style)
	assert(game.get_node("SharedShadow")._level_style.display_name == "Outer Blur")
	game.free()
	await frames()
	print("shadow_style_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
