extends Node

func box(parent: Node, at: Vector2, dimensions: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = at
	rect.size = dimensions
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

func _ready() -> void:
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	game.transitions_enabled = false
	add_child(game)
	var level := GameHandler.current_level
	level.fall_death_enabled = false
	var composer := game.get_node("SharedShadow") as SharedShadowComposer
	assert(level.material == null and composer.material is ShaderMaterial)
	assert(level.players.get_parent() == level)
	var camera := get_viewport().get_camera_2d() as LevelCamera
	camera.follow_enabled = false
	camera.global_position = Vector2(128,120)
	camera.force_update_scroll()
	level.player.set_gameplay_suspended(true)
	level.player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	level.player.body.global_position = Vector2(80,100)
	level.player.sprite.hide()
	level.active_area.get_node("Layouts").hide()
	level.active_area.get_node("WorldObjects").hide()
	for child in game.get_node("UI/HUD").get_children(): child.hide()
	box(level,Vector2(64,80),Vector2(16,16),Color.RED)
	box(game.get_node("UI/HUD"),Vector2(72,88),Vector2(16,16),Color.WHITE)
	box(level.player.body,Vector2(-4,-8),Vector2(8,8),Color.GREEN)
	var material := composer.material.duplicate() as ShaderMaterial
	composer.material = material
	material.set_shader_parameter("blur_radius",0.0)
	material.set_shader_parameter("shadow_offset",Vector2(4,4))
	material.set_shader_parameter("shadow_color",Color(0,0,0,0.5))
	composer.sync_rendering()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		assert(shot.get_pixel(77,94).is_equal_approx(Color.GREEN), "Player foreground must cover HUD.")
		assert(shot.get_pixel(85,94).is_equal_approx(Color.WHITE), "World shadows cannot darken HUD foreground.")
		assert(shot.get_pixel(66,82).is_equal_approx(Color.RED), "HUD shadow cannot cover world foreground.")
		var background := shot.get_pixel(110,110)
		var shadow := shot.get_pixel(90,106)
		assert(shadow.r < background.r - 0.05, "HUD must contribute to the shared shadow.")
		assert(shot.save_png("res://.godot/validation/shared-shadow-overlap.png") == OK)
		# Fractional camera motion must not move the HUD or inherit interpolation twice.
		for frame in range(6):
			camera.global_position.x += 0.25
			camera.force_update_scroll()
			await RenderingServer.frame_post_draw
			shot = get_viewport().get_texture().get_image()
			assert(shot.get_pixel(85,94).is_equal_approx(Color.WHITE))
	# Pipe travel retains the authored draw order without reparenting gameplay nodes.
	level.move_child(level.players,level.get_node("Areas").get_index())
	composer.sync_rendering()
	assert(composer._players_behind_world)
	level.move_child(level.players,level.get_child_count()-1)
	composer.sync_rendering()
	assert(not composer._players_behind_world and level.players.get_parent() == level)
	assert(GameHandler.load_level(game.initial_level))
	assert(composer._level == GameHandler.current_level)
	game.free()
	await get_tree().process_frame
	print("PASS: shared world/HUD/player composition, single shadow material, foreground occlusion, fractional-camera HUD stability, pipe draw ordering and level replacement.")
	get_tree().quit()
