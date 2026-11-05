extends Node
var starts: Array[StringName] = []


func tick(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame


func record_start(_id: int, kind: StringName) -> void:
	starts.append(kind)


func wait_for_transition() -> void:
	for frame in range(180):
		if GameHandler.transitions.busy:
			return
		await get_tree().physics_frame
	assert(false, "Start did not begin a transition")


func wait_for_play() -> void:
	for frame in range(180):
		if GameHandler.flow == GameHandler.GameFlow.PLAYING:
			return
		await get_tree().physics_frame
	assert(false, "Title did not enter gameplay")


func enter_key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ENTER
	event.pressed = pressed
	Input.parse_input_event(event)


func start_button(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 2
	event.button_index = JOY_BUTTON_START
	event.pressed = pressed
	Input.parse_input_event(event)


func _ready() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	assert(ControllerHandler.start_action == &"start")
	assert(ControllerHandler.select_action == &"select")
	var select_key := InputEventKey.new()
	select_key.physical_keycode = KEY_TAB
	select_key.pressed = true
	assert(select_key.is_action_pressed(&"select"))
	for key in [KEY_ENTER, KEY_KP_ENTER]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = true
		assert(event.is_action_pressed(&"start"))
	var button := InputEventJoypadButton.new()
	button.device = 2
	button.button_index = JOY_BUTTON_START
	button.pressed = true
	assert(button.is_action_pressed(&"start"))
	# Releasing confirmation during a transition must unblock a later fresh Jump.
	Input.action_press(ControllerHandler.primary_action)
	ControllerHandler.consume_menu_confirmation()
	ControllerHandler.enabled = false
	Input.action_release(ControllerHandler.primary_action)
	await tick(2)
	assert(not ControllerHandler._primary_requires_release)
	ControllerHandler.enabled = true
	var director: TransitionCoordinator = GameHandler.transitions
	var definition := director.get_definition(&"level")
	definition.minimum_frames = 2
	definition.stages[0].minimum_frames = 4
	definition.stages[1].minimum_frames = 2
	director.started.connect(record_start)
	for keyboard in [true, false]:
		starts.clear()
		var game: Node = load("res://scenes/main/game.tscn").instantiate()
		add_child(game)
		assert(game.start_with_title)
		assert(
			(
				GameHandler.flow == GameHandler.GameFlow.TITLE
				and not director.busy
				and starts.is_empty()
			)
		)
		var background := GameHandler.current_level
		assert(background.scene_file_path == "res://scenes/levels/test_level.tscn")
		assert(background.get_node("Areas").get_child_count() == 1)
		# Authored scenery may include blocks; title gameplay must remain frozen.
		for entity in background.find_children("*", "BaseEntity", true, false):
			assert(entity.gameplay_suspended and not entity.is_physics_processing())
		var mario := background.player
		assert(mario.gameplay_suspended and ControllerHandler.enabled)
		assert(not background.is_physics_processing())
		var title := game.get_node("UI/ScreenContainer/TitleScreen") as Control
		var label := title.get_node("PlayerOne") as Label
		var hud := game.get_node("UI/HUD") as Control
		assert(label.text == "1 PLAYER GAME")
		var copyright_label := title.get_node("Copyright") as Label
		assert(
			(
				copyright_label.text == "©1985 NINTENDO"
				and copyright_label.position == Vector2(104, 120)
			)
		)
		var accent := copyright_label.get_theme_font(&"font")
		var expected_accent := load("res://assets/palettes/overworld/ui/alphabet-alt.fnt") as Font
		if (
			background.active_area.theme != null
			and background.active_area.theme.title_accent_font != null
		):
			expected_accent = background.active_area.theme.title_accent_font
		assert(accent == expected_accent)
		assert(
			(
				accent.has_char(169)
				and (
					accent.get_string_size(copyright_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
					== 112
				)
			)
		)

		assert(
			(
				label.get_theme_font(&"font").resource_path
				== hud.get_theme_font(&"font", &"Label").resource_path
			)
		)
		assert(label.get_theme_color(&"font_color") == Color.WHITE)
		var cursor := title.get_node("Cursor") as Sprite2D
		assert(cursor.texture.get_size() == Vector2(8, 8))
		var area := background.active_area
		var original_theme := area.theme
		var canonical := load("res://assets/palettes/overworld/ui/start-cursor.png") as Texture2D
		var expected := (
			original_theme.resolve_texture(canonical) if original_theme != null else canonical
		)
		assert(cursor.texture == expected)
		var title_card := title.get_node("TitleCard") as Sprite2D
		var canonical_card := (
			load("res://assets/palettes/overworld/ui/start-title.png") as Texture2D
		)
		var expected_card := (
			original_theme.resolve_texture(canonical_card)
			if original_theme != null
			else canonical_card
		)
		assert(
			(
				title_card.texture == expected_card
				and title_card.texture.get_size() == Vector2(192, 96)
			)
		)
		assert(
			(
				title_card.position == Vector2(32, 32)
				and title_card.scale == Vector2.ONE
				and not title_card.centered
			)
		)
		area.theme = load("res://assets/themes/overworld.tres")
		assert(cursor.texture.resource_path.contains("/palettes/overworld/"))
		assert(
			(
				copyright_label.get_theme_font(&"font").resource_path
				== "res://assets/palettes/overworld/ui/alphabet-alt.fnt"
			)
		)
		assert(title_card.texture == canonical_card)
		area.theme = load("res://assets/themes/underground.tres")
		assert(
			cursor.texture.resource_path == "res://assets/palettes/underground/ui/start-cursor.png"
		)
		assert(
			(
				title_card.texture.resource_path
				== "res://assets/palettes/underground/ui/start-title.png"
			)
		)
		assert(
			(
				copyright_label.get_theme_font(&"font").resource_path
				== "res://assets/palettes/underground/ui/alphabet-alt.fnt"
			)
		)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			assert(
				(
					get_viewport().get_texture().get_image().save_png(
						"res://.godot/validation/title-underground-cursor.png"
					)
					== OK
				)
			)
		assert(label.get_theme_color(&"font_color") == Color.WHITE)
		# A title created with an Underground background joins the correct theme.
		var themed_title: Control = load("res://scenes/ui/title/title_screen.tscn").instantiate()
		game.get_node("UI/ScreenContainer").add_child(themed_title)
		assert(
			(themed_title.get_node("Cursor") as Sprite2D).texture.resource_path.contains(
				"/palettes/underground/"
			)
		)
		assert(
			(
				themed_title.get_node("Copyright").get_theme_font(&"font").resource_path
				== "res://assets/palettes/underground/ui/alphabet-alt.fnt"
			)
		)
		assert(
			(
				themed_title.get_node("TitleCard").texture.resource_path
				== "res://assets/palettes/underground/ui/start-title.png"
			)
		)
		themed_title.free()
		area.theme = AreaTheme.new()
		assert(title_card.texture == canonical_card)
		assert(cursor.texture.resource_path.contains("/palettes/overworld/"))
		area.theme = null
		assert(title_card.texture == canonical_card)
		assert(cursor.texture.resource_path.contains("/palettes/overworld/"))
		var accent_theme := AreaTheme.new()
		accent_theme.title_accent_font = hud.get_theme_font(&"font", &"Label")
		area.theme = accent_theme
		assert(copyright_label.get_theme_font(&"font") == accent_theme.title_accent_font)
		area.theme = original_theme
		assert(copyright_label.get_theme_font(&"font") == expected_accent)
		assert(title_card.texture == expected_card)
		assert(cursor.texture == expected)
		var source_title: Control = load("res://scenes/ui/title/title_screen.tscn").instantiate()
		assert(
			(source_title.get_node("Cursor") as Sprite2D).texture.resource_path.contains(
				"/palettes/overworld/"
			)
		)
		assert(source_title.get_node("TitleCard").texture == canonical_card)
		source_title.free()
		var origin := mario.body.global_position
		Input.action_press(ControllerHandler.right_action)
		Input.action_press(ControllerHandler.primary_action)
		await tick(90)
		assert(mario.body.global_position == origin and mario.gameplay_suspended)
		for entity in background.find_children("*", "BaseEntity", true, false):
			assert(entity.gameplay_suspended and not entity.is_physics_processing())
		assert(starts.is_empty() and GameHandler.flow == GameHandler.GameFlow.TITLE)
		Input.action_release(ControllerHandler.right_action)
		Input.action_release(ControllerHandler.primary_action)
		await tick(2)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			assert(
				(
					get_viewport().get_texture().get_image().save_png(
						"res://.godot/validation/title-screen.png"
					)
					== OK
				)
			)
		# Cancel before work: title and its suspended player return without a splash.
		assert(GameHandler.start_new_game())
		assert(not GameHandler.start_new_game())
		director.cancel()
		await tick(1)
		assert(GameHandler.flow == GameHandler.GameFlow.TITLE and not director.busy)
		assert(GameHandler.current_player.gameplay_suspended and ControllerHandler.enabled)
		starts.clear()
		title = GameHandler._title_screen
		assert(not title.has_node("PlayerTest"))
		Input.action_press(ControllerHandler.select_action)
		await tick(4)
		Input.action_release(ControllerHandler.select_action)
		await tick(2)
		assert(title.cursor.position == Vector2(72, 144))
		GameHandler.set_session_value(&"score", 999)
		if keyboard:
			enter_key(true)
		else:
			start_button(true)
		await wait_for_transition()
		assert(GameHandler.flow == GameHandler.GameFlow.STARTING)
		assert(not GameHandler.start_new_game())
		await wait_for_play()
		await tick(4)
		assert(starts == [&"level"])
		assert(
			(
				GameHandler.current_level.scene_file_path
				== "res://scenes/levels/worlds/world 1/1-1.tscn"
			)
		)
		assert(GameHandler._first_level == game.initial_level)
		assert(GameHandler.current_level != background)
		assert(background.is_shutdown if is_instance_valid(background) else true)
		assert(GameHandler.current_player.body.is_on_floor())
		assert(not GameHandler.current_player.gameplay_suspended)
		assert(GameHandler.get_session_value(&"score", 0) == 0)
		assert(GameHandler._title_screen == null)
		# Holding Enter across reveal cannot become an immediate Jump.
		assert(not ControllerHandler.input_primary_just_pressed)
		if keyboard:
			enter_key(false)
		else:
			start_button(false)
		await tick(2)
		Input.action_press(ControllerHandler.primary_action)
		await tick(2)
		assert(GameHandler.current_player.body.velocity.y < 0.0)
		Input.action_release(ControllerHandler.primary_action)
		# Let the verified fresh Jump's one-shot finish before destroying its player.
		var jump_audio := GameHandler.current_player._active_sound_effect
		while is_instance_valid(jump_audio) and jump_audio.playing:
			await tick(1)
		game.free()
		await get_tree().process_frame
		assert(
			GameHandler.flow == GameHandler.GameFlow.DETACHED and GameHandler._title_screen == null
		)
	# Alternate destinations remain available independently of visible menu entries.
	var alternate: Node = load("res://scenes/main/game.tscn").instantiate()
	add_child(alternate)
	assert(GameHandler.start_new_game(load("res://scenes/levels/test_level.tscn")))
	await wait_for_play()
	assert(GameHandler.current_level.scene_file_path == "res://scenes/levels/test_level.tscn")
	assert(GameHandler._first_level == alternate.initial_level)
	assert(not GameHandler.current_player.gameplay_suspended)
	alternate.free()
	await tick(2)
	# Detaching during Start must not recreate the title over a freed Game.
	var closing: Node = load("res://scenes/main/game.tscn").instantiate()
	add_child(closing)
	assert(GameHandler.start_new_game())
	closing.free()
	await tick(3)
	assert(
		not director.busy and GameHandler.current_game == null and GameHandler._title_screen == null
	)
	definition.minimum_frames = 12
	definition.stages[0].minimum_frames = 147
	definition.stages[1].minimum_frames = 12
	director.started.disconnect(record_start)
	print(
		"PASS: immediate title/no demo, suspended background Mario, white HUD font/cursor, Enter/gamepad Start, single visible option, once-only 1-1 load and retained alternate-stage launch, confirmation consumption, cancellation, session reset and detach cleanup."
	)
	get_tree().quit()
