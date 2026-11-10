extends Node


func frames() -> void:
	for i in range(4):
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _ready() -> void:
	var standalone := load("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
	var preview_area := standalone.get_node("Areas/MainArea") as BaseLevelArea
	preview_area.background_color = Color(0.125, 0.25, 0.5, 1)
	add_child(standalone)
	preview_area.get_node("Layouts").hide()
	preview_area.get_node("WorldObjects").hide()
	standalone.player.hide()
	await frames()
	assert(preview_area.get_node("Background").color == preview_area.background_color)
	if DisplayServer.get_name() != "headless":
		var preview := get_viewport().get_texture().get_image().get_pixel(40, 80)
		assert(absf(preview.b - preview_area.background_color.b) < 0.01)
	standalone.free()
	await frames()
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	game.start_with_title = false
	game.transitions_enabled = false
	game.shadow_shader_enabled = true
	game.shadow_style = load("res://assets/shadows/crisp.tres")
	add_child(game)
	var level := GameHandler.current_level
	level.set_physics_process(false)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.hide()
	var main := level.active_area
	main.set_physics_process(false)
	main.get_node("Layouts").hide()
	main.get_node("WorldObjects").hide()
	var camera := main.get_node("Camera2D") as LevelCamera
	camera.follow_enabled = false
	camera.position = Vector2(128, 120)
	camera.area_left = 32
	camera.area_right = 224
	main.background_color = Color(0.125, 0.25, 0.5, 1)
	var composer := game.get_node("SharedShadow") as SharedShadowComposer
	composer.sync_rendering()
	var fill := main.get_node("Background") as ColorRect
	assert(fill.position == Vector2(32, 0) and fill.size == Vector2(192, 240))
	assert(fill.get_parent() == main and composer._routed_background == fill)
	var foreground := ColorRect.new()
	foreground.position = Vector2(100, 80)
	foreground.size = Vector2(8, 8)
	foreground.color = Color.RED
	main.add_child(foreground)
	await frames()
	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		var inside := image.get_pixel(40, 80)
		assert(absf(inside.b - main.background_color.b) < 0.01)
		assert(image.get_pixel(16, 80).is_equal_approx(Color.BLACK))
		assert(image.get_pixel(225, 80).is_equal_approx(Color.BLACK))
		assert(image.get_pixel(103, 83).is_equal_approx(Color.RED))
		assert(
			image.get_pixel(109, 89).b < inside.b - 0.05,
			"Foreground shadow must fall on area fill."
		)
		assert(image.save_png("res://.godot/validation/area-background-crisp.png") == OK)
	main.background_color = Color(0, 0, 0, 0)
	composer.sync_rendering()
	await frames()
	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		assert(image.get_pixel(40, 80).is_equal_approx(image.get_pixel(16, 80)))
	# Repositioning the area keeps its camera bounds and fill attached.
	var lower := level.get_node("Areas/LowerArea") as BaseLevelArea
	lower.position += Vector2(64, 32)
	lower.background_color = Color(0.5, 0.25, 0.125, 1)
	assert(level.request_area_transfer(&"lower", &"arrival"))
	await frames()
	composer.sync_rendering()
	var lower_fill := lower.get_node("Background") as ColorRect
	assert(lower_fill.position == Vector2.ZERO and lower_fill.size == Vector2(256, 240))
	assert(lower_fill.global_position == lower.global_position)
	var lower_camera := lower.get_node("Camera2D") as LevelCamera
	assert(lower_camera.world_left == 960.0 and lower_camera.world_right == 1216.0)
	assert(lower_fill.color == lower.background_color)
	assert(composer._routed_background == lower_fill and not is_instance_valid(fill))
	game.shadow_style = null
	composer.sync_rendering()
	assert(composer.material == null)
	assert(lower_fill.color == lower.background_color)
	game.free()
	await frames()
	print("area_background_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
