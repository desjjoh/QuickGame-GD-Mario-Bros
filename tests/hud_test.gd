extends Node

func _ready() -> void:
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	add_child(game)
	var ui := game.get_node("UI") as Control
	var hud := ui.get_node("HUD") as Control
	assert(ui.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF)
	assert(not GameHandler.current_level.is_ancestor_of(ui))
	assert(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var values := {}
	for child in hud.get_children():
		if child is Label:
			assert(fmod(child.position.x,8.0) == 0.0 and fmod(child.position.y,8.0) == 0.0)
			assert(child.mouse_filter == Control.MOUSE_FILTER_IGNORE)
			values[child.name] = child.text
	var font := hud.get_theme_font(&"font", &"Label")
	for text in ["MARIO", "WORLD", "TIME", "000000", "1-1", "×00"]:
		assert(font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x == text.length()*8)
	var coin := hud.get_node("Coin") as AnimatedSprite2D
	assert(coin.sprite_frames.get_frame_count(&"default") == 4)
	assert(coin.sprite_frames.get_frame_duration(&"default",0) == 3.0)
	assert(coin.sprite_frames.get_animation_speed(&"default") == 7.5)
	assert(not coin.is_playing() and coin.get_node("Synchronization").enabled and coin.position == Vector2(88,24))
	await get_tree().create_timer(0.45).timeout
	var cycle := coin.get_node("Synchronization").cycle as CosmeticAnimationCycle
	assert(coin.frame == cycle.phase_at(GameHandler.animation_clock.tick_count))
	# Camera and area changes cannot move/recreate screen-space UI.
	game.get_node("SharedShadow").sync_rendering()
	var position_before := hud.get_global_transform_with_canvas()
	assert(GameHandler.current_level.request_area_transfer(&"lower"))
	await get_tree().process_frame
	# Headless mode has no pre-draw pass; explicitly synchronize that render contract.
	game.get_node("SharedShadow").sync_rendering()
	assert(game.get_node("UI/HUD") == hud and hud.get_global_transform_with_canvas().is_equal_approx(position_before))
	assert(GameHandler.load_level(game.initial_level))
	assert(game.get_node("UI/HUD") == hud)
	GameHandler.set_session_value(&"score",12345)
	for name in values: assert(hud.get_node(NodePath(name)).text == values[name])
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png("res://.godot/validation/hud-game.png") == OK)
	# A transition screen is hosted beneath the same HUD, outside the level.
	var transition := ColorRect.new()
	transition.color = Color.BLACK
	transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.get_node("ScreenContainer").add_child(transition)
	assert(ui.get_node("ScreenContainer").get_index() < hud.get_index())
	assert(hud.is_visible_in_tree())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png("res://.godot/validation/hud-transition.png") == OK)
	game.free()
	await get_tree().process_frame
	print("PASS: 8x8 HUD font/layout, coin cadence, input pass-through, static values and UI identity across camera/area/level changes and transition overlay.")
	get_tree().quit()
