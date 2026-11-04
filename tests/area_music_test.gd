extends Node


func _ready() -> void:
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	game.start_with_title = false
	game.transitions_enabled = false
	add_child(game)
	var level := GameHandler.current_level
	var main := level.active_area
	var lower := level.get_node("Areas/LowerArea") as BaseLevelArea
	assert(main.is_active and not lower.is_active and not lower.runtime_loaded)
	main.enter_area()
	assert(main.is_active)
	lower.load_runtime({})
	assert(lower.runtime_loaded and not lower.is_active, "Preloading does not enter an area.")
	lower.unload_runtime()
	assert(level.request_area_transfer(&"lower"))
	await get_tree().process_frame
	assert(
		lower.is_active and lower.runtime_loaded and not main.is_active and not main.runtime_loaded
	)
	assert(
		level.find_children("*", "AudioStreamPlayer", true, false).is_empty(),
		"Areas must not create soundtrack players."
	)
	assert(level.request_area_transfer(&"main"))
	await get_tree().process_frame
	assert(main.is_active and not lower.is_active)
	level.shutdown()
	assert(not main.is_active and not lower.is_active)
	game.free()
	print(
		"PASS: area entry, preload, cross-area handoff and shutdown retain lifecycle without soundtrack playback."
	)
	get_tree().quit()
