extends Node

var preparations := 0
var prepared_during_transition := false


func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func inject_markers(level: BaseLevel) -> void:
	assert(
		not level.active_area.actors_initialized, "Loading must not activate spawners implicitly."
	)
	if GameHandler.flow != GameHandler.GameFlow.TITLE:
		return
	preparations += 1
	prepared_during_transition = prepared_during_transition or level.transition_in_progress
	# Isolate title scenery from user edits without changing the authored scene.
	for node in level.world_objects.get_children():
		if node is EntitySpawner and node.spawn_category == &"enemy":
			node.shutdown()
			node.free()
	var layout := TileMapLayer.new()
	layout.tile_set = level.active_area.theme.enemy_markers
	layout.set_cell(Vector2i(12, 12), 0, Vector2i.ZERO)
	layout.set_cell(Vector2i(14, 12), 2, Vector2i.ZERO)
	level.active_area.get_node("Layouts").add_child(layout)
	level._spawn_layout_entities(level.active_area, layout, {})
	layout.free()
	assert(level.world_objects.get_node("goomba_spawner_12_12").get_node_or_null("Goomba") == null)
	assert(
		(
			level.world_objects.get_node("green_koopa_spawner_14_12").get_node_or_null("GreenKoopa")
			== null
		)
	)


func check_backdrop() -> void:
	var level: BaseLevel = GameHandler.current_level
	var goomba := level.world_objects.get_node("goomba_spawner_12_12/Goomba") as BaseEnemy
	var koopa := level.world_objects.get_node("green_koopa_spawner_14_12/GreenKoopa") as BaseEnemy
	assert(goomba != null and koopa != null)
	assert(not level.is_physics_processing())
	for entity in level.find_children("*", "BaseEntity", true, false):
		assert(entity.gameplay_suspended and not entity.is_physics_processing())
	var positions := [goomba.body.global_position, koopa.body.global_position]
	level.initialize_actors(true)
	assert(level._live_spawns[&"enemy"].size() == 2)
	await ticks(10)
	assert([goomba.body.global_position, koopa.body.global_position] == positions)
	assert(not level.death_in_progress)


func _ready() -> void:
	GameHandler.level_changed.connect(inject_markers)
	var game: Node = load("res://scenes/main/game.tscn").instantiate()
	game.stages.assign([load("res://scenes/levels/worlds/world 1/1-1.tscn")])
	add_child(game)
	await check_backdrop()
	assert(preparations == 1 and not prepared_during_transition)
	assert(GameHandler.start_new_game())
	for frame in range(300):
		await ticks(1)
		if GameHandler.flow == GameHandler.GameFlow.PLAYING and not GameHandler.transitions.busy:
			break
	assert(GameHandler.flow == GameHandler.GameFlow.PLAYING)
	assert(GameHandler.current_level.on_complete())
	for frame in range(300):
		await ticks(1)
		if GameHandler.flow == GameHandler.GameFlow.TITLE and not GameHandler.transitions.busy:
			break
	assert(GameHandler.flow == GameHandler.GameFlow.TITLE and preparations == 2)
	assert(prepared_during_transition)
	await check_backdrop()
	GameHandler.level_changed.disconnect(inject_markers)
	game.queue_free()
	await ticks(2)
	print("title_backdrop_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
