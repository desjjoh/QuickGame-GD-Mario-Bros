extends Node
var changes: Array[StringName] = []


func record_change(key: StringName, _value: Variant) -> void:
	changes.append(key)


func ticks(count: int = 2) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	GameHandler.clear_session()
	GameHandler.set_top_score(43210)
	var status := GameHandler.player_status
	assert(status.score == 0 and status.coins == 0 and status.lives == 2)
	assert(status.powerup_form == PlayerStatus.PowerupForm.SMALL)
	var game: Node = load("res://scenes/main/game.tscn").instantiate()
	game.transitions_enabled = false
	add_child(game)
	var hud := game.get_node("UI/HUD")
	var title := game.get_node("UI/ScreenContainer/TitleScreen")
	assert(title.get_node("TopScore").text == "TOP- 043210")
	var top_label := title.get_node("TopScore") as Label
	assert(top_label.position == Vector2(96, 184))
	assert(top_label.get_theme_font(&"font") == hud.get_theme_font(&"font", &"Label"))
	GameHandler.session_value_changed.connect(record_change)
	GameHandler.add_score(250)
	GameHandler.add_coins(7)
	GameHandler.set_lives(5)
	GameHandler.set_player_form(PlayerStatus.PowerupForm.FIRE)
	assert(hud.get_node("Score").text == " 000250" and hud.get_node("CoinCount").text == "07")
	assert(status.powerup_form == PlayerStatus.PowerupForm.FIRE)
	var count := changes.size()
	GameHandler.set_score(250)
	assert(changes.size() == count, "Unchanged status must not emit duplicate updates.")
	GameHandler.set_session_value(&"score", 12345)
	assert(status.score == 12345 and not GameHandler._session.has(&"score"))
	assert(
		GameHandler.get_session_value(&"score") == 12345 and hud.get_node("Score").text == " 012345"
	)
	GameHandler.set_top_score(54321)
	assert(top_label.text == "TOP- 054321")
	GameHandler.set_score(1000000)
	GameHandler.set_coins(100)
	assert(status.score == 999999 and status.coins == 99)
	assert(
		status.lives == 5 and GameHandler.top_score == 54321,
		"Coin rewards are deferred; score changes do not promote the record before title return."
	)
	GameHandler.set_score(-1)
	GameHandler.set_coins(-1)
	assert(status.score == 0 and status.coins == 0)
	GameHandler.set_score(1200)
	GameHandler.set_coins(9)
	GameHandler.stage_label = "2-3"
	GameHandler.time_remaining = 321
	assert(hud.get_node("WorldValue").text == "2-3" and hud.get_node("TimeValue").text == "321")
	GameHandler.stage_label = "TEST LEVEL"
	assert(hud.get_node("WorldValue").text == "TES" and GameHandler.stage_label == "TEST LEVEL")
	GameHandler.stage_label = "2"
	assert(hud.get_node("WorldValue").text == "2")
	assert(hud.get_node("WorldValue").horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT)
	assert(hud.get_node("WorldValue").size.x == 24.0)
	GameHandler.stage_label = "2-3"
	var intro: Node = load("res://scenes/ui/transitions/level_intro.tscn").instantiate()
	game.get_node("UI/ScreenContainer").add_child(intro)
	assert(intro.get_node("World").text == "WORLD 2-3" and intro.get_node("Lives").text == "6")
	var lives_label := intro.get_node("Lives") as Label
	assert(intro.get_node("LivesMultiplier").text == "×")
	assert(lives_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT)
	assert(lives_label.position == Vector2(136, 112) and lives_label.size.x == 16)
	GameHandler.set_lives(12)
	assert(lives_label.text == "13" and lives_label.size.x == 16)
	GameHandler.set_lives(4)
	assert(intro.get_node("Lives").text == "5")
	intro.free()
	assert(GameHandler.start_new_game())
	assert(GameHandler.flow == GameHandler.GameFlow.PLAYING)
	assert(GameHandler.player_status == status)
	assert(
		(
			status.score == 0
			and status.coins == 0
			and status.lives == 2
			and status.powerup_form == PlayerStatus.PowerupForm.SMALL
		)
	)
	assert(GameHandler.top_score == 54321 and hud.get_node("Score").text == " 000000")
	GameHandler.add_score(100)
	GameHandler.add_coins(8)
	var level := GameHandler.current_level
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	GameHandler.time_remaining = 250
	assert(level.request_area_transfer(&"lower"))
	await ticks()
	assert(GameHandler.player_status == status and status.score == 100 and status.coins == 8)
	assert(GameHandler.stage_label == "1-1" and GameHandler.time_remaining == 250)
	assert(GameHandler.restart_after_death(level, level._progress_key))
	assert(
		(
			GameHandler.player_status == status
			and status.score == 100
			and status.coins == 8
			and status.lives == 2
		)
	)
	assert(GameHandler.time_remaining == 400 and GameHandler.top_score == 54321)
	assert(game.get_node("UI/HUD") == hud and hud.get_node("CoinCount").text == "08")
	await ticks()
	# Returning to title promotes the final run score before clearing it.
	GameHandler.set_score(60000)
	assert(GameHandler.top_score == 54321, "Promotion belongs to title return, not score mutation.")
	assert(GameHandler.show_title(game.initial_level))
	assert(GameHandler.top_score == 60000 and status.score == 0 and status.coins == 0)
	assert(game.get_node("UI/ScreenContainer/TitleScreen/TopScore").text == "TOP- 060000")
	# Ties and lower scores preserve the record without emitting a new record update.
	for final_score in [60000, 1200]:
		GameHandler.set_score(final_score)
		changes.clear()
		assert(GameHandler.show_title(game.initial_level))
		assert(GameHandler.top_score == 60000 and status.score == 0)
		assert(not changes.has(&"top_score"))
		assert(game.get_node("UI/ScreenContainer/TitleScreen/TopScore").text == "TOP- 060000")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(
			(
				get_viewport().get_texture().get_image().save_png(
					"res://.godot/validation/player-status-title.png"
				)
				== OK
			)
		)
	GameHandler.session_value_changed.disconnect(record_change)
	game.free()
	await ticks()
	assert(GameHandler.top_score == 60000)
	GameHandler.clear_session()
	assert(
		(
			status.score == 0
			and status.coins == 0
			and status.lives == 2
			and GameHandler.top_score == 60000
		)
	)
	print(
		"PASS: typed status defaults/ranges, signals, live HUD/title/intro, new-game reset, title-return record promotion/tie/lower-score handling, area/death continuity and no automatic coin rewards"
	)
	get_tree().quit()
