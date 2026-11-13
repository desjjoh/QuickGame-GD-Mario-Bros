extends Node


func check_background(label: String) -> void:
	var level := GameHandler.current_level
	assert(GameHandler.flow == GameHandler.GameFlow.TITLE)
	assert(level.stage_label == label and GameHandler.current_stage_index == -1)
	assert(not level.has_started and not level.is_physics_processing())
	for entity in level.find_children("*", "BaseEntity", true, false):
		assert(entity.gameplay_suspended)


func _ready() -> void:
	var level_scene := load("res://tests/fixtures/silent_level.tscn") as PackedScene
	var fixture := level_scene.instantiate() as BaseLevel
	fixture.stage_label = "MENU"
	var custom := PackedScene.new()
	assert(custom.pack(fixture) == OK)
	fixture.free()
	var game_scene := load("res://scenes/main/game.tscn") as PackedScene
	var game = game_scene.instantiate()
	var first_stage: PackedScene = game.stages[0]
	game.stages.assign([first_stage])
	game.title_background = custom
	game.transitions_enabled = false
	game.start_stage_override = null
	add_child(game)
	check_background("MENU")
	assert(game.stages[0] == first_stage)
	assert(GameHandler.start_new_game())
	assert(GameHandler.current_level.scene_file_path == first_stage.resource_path)
	assert(GameHandler.current_level.has_started)
	assert(GameHandler.current_level.on_complete())
	check_background("MENU")
	# Re-read the Game selection on later returns, not a cached title-scene default.
	fixture = level_scene.instantiate() as BaseLevel
	fixture.stage_label = "ALT MENU"
	var alternate := PackedScene.new()
	assert(alternate.pack(fixture) == OK)
	fixture.free()
	game.title_background = alternate
	assert(GameHandler.start_new_game())
	assert(GameHandler.current_level.on_complete())
	check_background("ALT MENU")
	# Empty selection falls back to the first configured stage on title return.
	game.title_background = null
	assert(GameHandler.start_new_game())
	assert(GameHandler.current_level.on_complete())
	assert(GameHandler.current_level.scene_file_path == first_stage.resource_path)
	check_background(GameHandler.current_level.stage_label)
	game.free()
	await get_tree().process_frame
	# The same fallback applies at startup.
	game = game_scene.instantiate()
	game.title_background = null
	game.start_stage_override = game.stages[1]
	game.transitions_enabled = false
	add_child(game)
	assert(GameHandler.current_level.scene_file_path == game.stages[0].resource_path)
	check_background(GameHandler.current_level.stage_label)
	assert(GameHandler.start_new_game())
	assert(GameHandler.current_level.scene_file_path == game.start_stage_override.resource_path)
	assert(GameHandler.current_stage_index == 1 and GameHandler.current_level.stage_label == "1-2")
	assert(GameHandler.current_level.active_area.area_id == &"intro")
	game.free()
	await get_tree().process_frame
	print("title_background_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
