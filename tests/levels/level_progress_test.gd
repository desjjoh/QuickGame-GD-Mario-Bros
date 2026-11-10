extends Node


func _ready() -> void:
	GameHandler.clear_session()
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	add_child(game)
	var source := GameHandler.current_level
	var key := source._progress_key
	var data := {"used_blocks": [Vector2i(4, 9)], "collected_coins": [Vector2i(6, 8)]}
	GameHandler.store_area_progress(key, &"probe", data, source)
	data.used_blocks.clear()
	assert(GameHandler.get_area_progress(key, &"probe").used_blocks.size() == 1)
	var copy := GameHandler.get_area_progress(key, &"probe")
	copy.collected_coins.clear()
	assert(GameHandler.get_area_progress(key, &"probe").collected_coins.size() == 1)
	assert(GameHandler._area_progress.has(&"probe") and not GameHandler._area_progress.has(key))
	assert(GameHandler.load_level(game.stages[0]))
	assert(GameHandler.get_area_progress(key, &"probe").used_blocks.size() == 1)
	var level := GameHandler.current_level
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	assert(level.request_area_transfer(&"lower"))
	await get_tree().process_frame
	assert(GameHandler.get_area_progress(key, &"probe").collected_coins.size() == 1)
	assert(level.request_area_transfer(&"main", &"player_spawn"))
	await get_tree().process_frame
	assert(GameHandler._progress_level_key == key)
	# Visit another logical level, then return; the old visit must not resurrect.
	var previous := GameHandler.current_level
	var sandbox_scene := load("res://tests/fixtures/sandbox_level.tscn") as PackedScene
	assert(GameHandler.load_level(sandbox_scene))
	assert(GameHandler._progress_level_key != key)
	assert(GameHandler.get_area_progress(key, &"probe").is_empty())
	GameHandler.store_area_progress(key, &"probe", {"stale": true}, previous)
	assert(GameHandler.get_area_progress(key, &"probe").is_empty())
	assert(GameHandler.load_level(game.stages[0]))
	assert(
		(
			GameHandler._progress_level_key == key
			and GameHandler.get_area_progress(key, &"probe").is_empty()
		)
	)
	GameHandler.store_area_progress(key, &"probe", {"stale": true}, previous)
	assert(
		GameHandler.get_area_progress(key, &"probe").is_empty(),
		"Old visit cannot write into a new visit of the same level."
	)
	# Title owns clearing even when gameplay and background are the same scene.
	game.title_background = sandbox_scene
	assert(GameHandler.load_level(sandbox_scene))
	var test_key := GameHandler.current_level._progress_key
	GameHandler.store_area_progress(test_key, &"probe", {"used": true}, GameHandler.current_level)
	assert(GameHandler.show_title(game.stages[0]))
	assert(GameHandler.current_level._progress_key == test_key)
	assert(GameHandler.get_area_progress(test_key, &"probe").is_empty())
	game.free()
	await get_tree().process_frame
	GameHandler.clear_session()
	assert(GameHandler._area_progress.is_empty() and GameHandler._progress_level_key.is_empty())
	print(
		"PASS: one-level area store, copied values, same-level/area preservation, different-level reset and stale-source rejection"
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
