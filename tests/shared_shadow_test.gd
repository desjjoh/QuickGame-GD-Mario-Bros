extends Node


func box(parent: Node, at: Vector2, dimensions: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = at
	rect.size = dimensions
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func sample_alpha(source: Image, point: Vector2) -> float:
	var base := Vector2i(point.floor())
	var fraction := point - Vector2(base)
	var values: Array[float] = []
	for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		var at: Vector2i = base + offset
		values.append(
			(
				source.get_pixelv(at).a
				if Rect2i(Vector2i.ZERO, source.get_size()).has_point(at)
				else 0.0
			)
		)
	return lerpf(
		lerpf(values[0], values[1], fraction.x), lerpf(values[2], values[3], fraction.x), fraction.y
	)


func reference_blur(source: Image, point: Vector2, radius: float) -> float:
	var alpha := 0.0
	var total := 0.0
	for y in range(-6, 7):
		for x in range(-6, 7):
			var weight := exp(-float(x * x + y * y) / 8.0)
			alpha += sample_alpha(source, point + Vector2(x, y) * radius / 6.0) * weight
			total += weight
	return alpha / total


func _ready() -> void:
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	game.shadow_shader_enabled = true
	game.start_with_title = false
	game.transitions_enabled = false
	add_child(game)
	var level := GameHandler.current_level
	level.fall_death_enabled = false
	var composer := game.get_node("SharedShadow") as SharedShadowComposer
	assert(level.material == null and composer.material is ShaderMaterial)
	assert(level.players.get_parent() == level)
	var camera := get_viewport().get_camera_2d() as LevelCamera
	camera.follow_enabled = false
	camera.global_position = Vector2(128, 120)
	camera.force_update_scroll()
	level.player.set_gameplay_suspended(true)
	level.player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	level.player.body.global_position = Vector2(80, 100)
	level.player.sprite.hide()
	level.active_area.get_node("Layouts").hide()
	level.active_area.get_node("WorldObjects").hide()
	for child in game.get_node("UI/HUD").get_children():
		child.hide()
	box(level, Vector2(64, 80), Vector2(16, 16), Color.RED)
	box(game.get_node("UI/HUD"), Vector2(72, 88), Vector2(16, 16), Color.WHITE)
	box(level.player.body, Vector2(-4, -8), Vector2(8, 8), Color.GREEN)
	var material := composer._level_material.duplicate() as ShaderMaterial
	composer._level_material = material
	material.set_shader_parameter("blur_radius", 0.0)
	material.set_shader_parameter("shadow_offset", Vector2(4, 4))
	material.set_shader_parameter("shadow_color", Color(0, 0, 0, 0.5))
	composer.sync_rendering()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		assert(
			shot.get_pixel(77, 94).is_equal_approx(Color.GREEN), "Player foreground must cover HUD."
		)
		assert(
			shot.get_pixel(85, 94).is_equal_approx(Color.WHITE),
			"World shadows cannot darken HUD foreground."
		)
		assert(
			shot.get_pixel(66, 82).is_equal_approx(Color.RED),
			"HUD shadow cannot cover world foreground."
		)
		var background := shot.get_pixel(110, 110)
		var shadow := shot.get_pixel(90, 106)
		assert(shadow.r < background.r - 0.05, "HUD must contribute to the shared shadow.")
		assert(shot.save_png("res://.godot/validation/shared-shadow-overlap.png") == OK)
		# Fractional camera motion must not move the HUD or inherit interpolation twice.
		for frame in range(6):
			camera.global_position.x += 0.25
			camera.force_update_scroll()
			await RenderingServer.frame_post_draw
			shot = get_viewport().get_texture().get_image()
			assert(shot.get_pixel(85, 94).is_equal_approx(Color.WHITE))
	if DisplayServer.get_name() != "headless":
		material.set_shader_parameter("blur_radius", 4.5)
		composer.sync_rendering()
		for frame in range(3):
			await RenderingServer.frame_post_draw
		var foreground := composer._source.get_texture().get_image()
		var blurred := get_viewport().get_texture().get_image()
		var backdrop := blurred.get_pixel(110, 110)
		var padding := Vector2.ONE * composer.SHADOW_PADDING
		for point in [
			Vector2i(89, 101),
			Vector2i(90, 103),
			Vector2i(90, 106),
			Vector2i(92, 102),
			Vector2i(68, 100)
		]:
			var original_alpha := sample_alpha(foreground, Vector2(point) + padding)
			assert(original_alpha == 0.0)
			var shadow_alpha := (
				reference_blur(foreground, Vector2(point) + padding - Vector2(4, 4), 4.5) * 0.5
			)
			var expected := backdrop.r * (1.0 - shadow_alpha)
			assert(
				absf(blurred.get_pixelv(point).r - expected) < 0.02,
				"Separable blur must match the original Gaussian alpha."
			)
		assert(blurred.save_png("res://.godot/validation/shared-shadow-two-pass.png") == OK)
	if DisplayServer.get_name() != "headless":
		# Every pass must consume this frame's image, without adding a frame of latency.
		var marker := box(game.get_node("UI/HUD"), Vector2(200, 160), Vector2(2, 2), Color.BLUE)
		for frame in range(8):
			marker.position.x = 200 + frame
			marker.color = Color.BLUE if frame % 2 == 0 else Color.RED
			await RenderingServer.frame_post_draw
			var current := get_viewport().get_texture().get_image()
			assert(
				current.get_pixel(200 + frame, 160).is_equal_approx(marker.color),
				"Blur passes must not delay the foreground by a frame."
			)
		marker.free()
	assert(composer._source.size == Vector2i(280, 264))
	# Bypass the complete effect rather than leaving the expensive shader attached.
	var original_material := composer.material
	game.shadow_shader_enabled = false
	assert(composer.material == null and level.material == null)
	assert(composer._source.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	assert(composer._horizontal.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	composer.sync_rendering()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var unshaded := get_viewport().get_texture().get_image()
		assert(unshaded.get_pixel(85, 94).is_equal_approx(Color.WHITE))
		assert(unshaded.get_pixel(90, 106).is_equal_approx(unshaded.get_pixel(110, 110)))
		assert(unshaded.save_png("res://.godot/validation/shared-shadow-disabled.png") == OK)
	game.shadow_shader_enabled = true
	assert(composer.material == original_material)
	game.shadow_shader_enabled = false
	# Pipe travel retains the authored draw order without reparenting gameplay nodes.
	level.move_child(level.players, level.get_node("Areas").get_index())
	composer.sync_rendering()
	assert(composer._players_behind_world)
	level.move_child(level.players, level.get_child_count() - 1)
	composer.sync_rendering()
	assert(not composer._players_behind_world and level.players.get_parent() == level)
	assert(GameHandler.load_level(game.initial_level))
	assert(composer._level == GameHandler.current_level)
	assert(composer.material == null and GameHandler.current_level.material == null)
	game.shadow_shader_enabled = true
	assert(composer.material == composer._composite and composer.material is ShaderMaterial)
	game.free()
	await get_tree().process_frame
	# The saved Inspector switch must also work before Game._ready executes.
	game = load("res://scenes/main/game.tscn").instantiate() as Node
	game.shadow_shader_enabled = false
	game.start_with_title = false
	game.transitions_enabled = false
	add_child(game)
	composer = game.get_node("SharedShadow") as SharedShadowComposer
	assert(composer.material == null and GameHandler.current_level.material == null)
	game.free()
	await get_tree().process_frame
	print(
		"PASS: shared world/HUD/player composition, two-pass Gaussian/reference agreement, foreground occlusion, fractional-camera HUD stability, pipe draw ordering, shader bypass/restore and disabled startup/level replacement."
	)
	get_tree().quit()
