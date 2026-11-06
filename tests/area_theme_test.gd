extends Node


func _ready() -> void:
	var castle := load("res://assets/themes/castle.tres") as AreaTheme
	var underground := load("res://assets/themes/underground.tres") as AreaTheme
	var flag := load("res://assets/palettes/overworld/misc/flagpole-flag.png") as Texture2D
	assert(castle.resolve_texture(flag).resource_path.contains("/castle/"))
	assert(underground.resolve_texture(flag).resource_path.contains("/underground/"))
	var underground_castle := underground.entity_markers.get_source(6) as TileSetAtlasSource
	assert(underground_castle.texture.resource_path.contains("/underground/"))
	assert(underground_castle.get_tile_data(Vector2i.ZERO, 0).get_custom_data("entity_id") == "castle")
	assert(castle.title_accent_font != null)
	assert(castle.terrain.get_source_count() == 2)
	assert(castle.decorations.get_source_count() == 4)
	for source_id in [3, 4, 5, 6]:
		var marker := castle.entity_markers.get_source(source_id) as TileSetAtlasSource
		assert(marker.texture.resource_path.contains("/castle/"))
	var level := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	# Editing and saving nested areas must retain each painted layer and camera.
	var saved_cells: Dictionary = {}
	for area_name in ["MainArea", "LowerArea"]:
		var area := level.get_node("Areas/" + area_name)
		assert(level.is_editable_instance(area))
		for layer in area.get_node("Layouts").get_children():
			saved_cells[area_name + "/" + str(layer.name)] = layer.tile_map_data.duplicate()
	var packed := PackedScene.new()
	assert(packed.pack(level) == OK)
	assert(ResourceSaver.save(packed, "res://.godot/validation/area-save-roundtrip.tscn") == OK)
	level.free()
	level = (
		(
			(
				ResourceLoader.load(
					"res://.godot/validation/area-save-roundtrip.tscn",
					"PackedScene",
					ResourceLoader.CACHE_MODE_IGNORE
				)
				as PackedScene
			)
			. instantiate()
		)
		as BaseLevel
	)
	for path: String in saved_cells:
		var parts := path.split("/")
		assert(
			(
				level.get_node("Areas/" + parts[0] + "/Layouts/" + parts[1]).tile_map_data
				== saved_cells[path]
			)
		)
	assert(level.get_node("Areas/MainArea/Camera2D").enabled)
	assert(not level.get_node("Areas/LowerArea/Camera2D").enabled)
	for area_name in ["MainArea", "LowerArea"]:
		var markers := (
			level.get_node("Areas/" + area_name + "/Layouts/EntityLayout") as TileMapLayer
		)
		markers.set_cell(Vector2i(2, 5), 7, Vector2i.ZERO)
	add_child(level)
	var main := level.get_node("Areas/MainArea") as BaseLevelArea
	var lower := level.get_node("Areas/LowerArea") as BaseLevelArea
	var main_coin := main.get_node("WorldObjects/coin_2_5") as BaseEntity
	assert(main_coin.position == Vector2(32, 80))
	assert(main_coin.sprite.texture.resource_path.contains("/palettes/overworld/"))
	assert(main.theme.display_name == "Overworld")
	assert(lower.theme.display_name == "Underground")
	var main_ground := main.get_node("Layouts/GroundLayout") as TileMapLayer
	assert(not lower.runtime_loaded and not lower.has_node("Layouts"))
	var main_terrain := main_ground.tile_set
	var main_decorations := main.theme.decorations
	GameHandler.set_coins(98)
	var main_player := level.player
	main_player.set_physics_process(false)
	main_player.body.global_position = main_coin.global_position + Vector2(8, 16)
	for frame in range(4):
		await get_tree().physics_frame
	assert(GameHandler.player_status.coins == 99 and GameHandler.player_status.score == 200)
	assert(GameHandler.player_status.lives == 2)
	var reward_voice := GameHandler.get_node("Square2Sfx") as AudioStreamPlayer
	assert(reward_voice.playing and reward_voice.stream == GameHandler._coin_one_shot)
	assert(level.request_area_transfer(&"lower"))
	await get_tree().process_frame
	assert(lower.runtime_loaded and not main.runtime_loaded)
	var lower_coin := lower.get_node("WorldObjects/coin_2_5") as BaseEntity
	assert(lower_coin.position == Vector2(32, 80))
	assert(lower_coin.sprite.texture.resource_path.contains("/palettes/underground/"))
	var lower_ground := lower.get_node("Layouts/GroundLayout") as TileMapLayer
	assert(main_terrain != lower_ground.tile_set)
	assert(
		(main_terrain.get_source(0) as TileSetAtlasSource).texture.resource_path.contains(
			"/palettes/overworld/"
		)
	)
	assert(
		(lower_ground.tile_set.get_source(0) as TileSetAtlasSource).texture.resource_path.contains(
			"/palettes/underground/"
		)
	)
	assert(main_terrain.get_source_count() == 2 and lower_ground.tile_set.get_source_count() == 2)
	for source_id in [0, 1]:
		var original := main_terrain.get_source(source_id) as TileSetAtlasSource
		var themed := lower_ground.tile_set.get_source(source_id) as TileSetAtlasSource
		assert(themed.texture.resource_path.contains("/palettes/underground/"))
		assert(themed.get_tiles_count() == (10 if source_id == 1 else 7))
		assert(original.get_tiles_count() == themed.get_tiles_count())
		for tile_index in range(original.get_tiles_count()):
			var coords := original.get_tile_id(tile_index)
			assert(themed.has_tile(coords))
			assert(themed.get_tile_data(coords, 0).get_collision_polygons_count(0) == 1)
	var lower_decorations := (lower.get_node("Layouts/DecorationLayout") as TileMapLayer).tile_set
	assert(main_decorations != lower_decorations and lower_decorations == lower.theme.decorations)
	assert(
		(
			lower_decorations.tile_size == Vector2i(16, 16)
			and lower_decorations.get_physics_layers_count() == 0
		)
	)
	assert(main_decorations.get_source_count() == 4 and lower_decorations.get_source_count() == 4)
	for index in range(main_decorations.get_source_count()):
		var id := main_decorations.get_source_id(index)
		assert(lower_decorations.has_source(id))
		var original := main_decorations.get_source(id) as TileSetAtlasSource
		var themed := lower_decorations.get_source(id) as TileSetAtlasSource
		assert(
			(
				themed.texture.resource_path
				== original.texture.resource_path.replace("/overworld/", "/underground/")
			)
		)
		assert(themed.texture.get_size() == original.texture.get_size())
		assert(themed.get_tiles_count() == original.get_tiles_count())
		if id == 15:
			assert(themed.get_tiles_count() == 7 and not themed.has_tile(Vector2i.ZERO))
			assert(not original.has_tile(Vector2i.ZERO))
		for tile_index in range(original.get_tiles_count()):
			var coords := original.get_tile_id(tile_index)
			assert(themed.has_tile(coords) and themed.has_alternative_tile(coords, 0))
		assert(original.texture.resource_path.contains("/palettes/overworld/"))
	var originals := (
		load("res://scenes/entities/blocks/brick/brick_block.tscn").instantiate() as BaseBlock
	)
	var original_texture: Texture2D = originals.get_node("Sprite2D").texture
	originals.free()
	var underground_count := 0
	for block in lower.get_node("WorldObjects").get_children():
		assert(block.visual_theme == lower.theme)
		if block.sprite.texture.resource_path.contains("brick"):
			underground_count += 1
			assert(block.sprite.texture.resource_path.contains("/palettes/underground/"))
			var texture: Texture2D = block.sprite.texture
			assert(block.receive_hit(EntityHit.new(null, &"bonk", Vector2.UP)))
			for frame in range(30):
				block.state_machine.process_physics(1.0 / 60.0)
			assert(
				(
					block.sprite.texture == texture
					and block.state_machine.current_state.name == &"Active"
				)
			)
	assert(underground_count > 0)
	assert(original_texture.resource_path.contains("/palettes/overworld/"))
	# Same painted IDs, different tile textures, and no shared resource mutation.
	assert(
		lower.theme.resolve_texture(original_texture).resource_path.contains(
			"/palettes/underground/"
		)
	)
	assert(main.theme.resolve_texture(original_texture) == original_texture)
	# Every supplied counterpart is mapped, including all question animation frames.
	assert(lower.theme.texture_overrides.size() == 23)
	for source_path: String in lower.theme.texture_overrides:
		var replacement := lower.theme.resolve_texture(load(source_path))
		assert(
			(
				replacement.resource_path
				== source_path.replace("palettes/overworld", "palettes/underground")
			)
		)
		assert(replacement.get_size() == (load(source_path) as Texture2D).get_size())
	for scene_path in [
		"res://scenes/entities/pipes/pipe_entrance.tscn",
		"res://scenes/entities/pipes/sideways_pipe_entrance.tscn"
	]:
		var pipe := load(scene_path).instantiate() as PipeEntrance
		pipe.visual_theme = lower.theme
		lower.get_node("WorldObjects").add_child(pipe)
		for visual in pipe.get_node("Visuals").get_children():
			assert(visual.texture.resource_path.contains("/palettes/underground/"))
	for source_id in range(5):
		var marker := lower.theme.entity_markers.get_source(source_id) as TileSetAtlasSource
		assert(
			(
				marker.texture.resource_path.contains("/palettes/underground/")
				or marker.texture.resource_path.contains("underground/previews")
			)
		)
	var question := (
		load("res://scenes/entities/blocks/question/question_block.tscn").instantiate() as BaseBlock
	)
	question.visual_theme = lower.theme
	lower.get_node("WorldObjects").add_child(question)
	for sample in [
		[0.0, "question-block.tres"], [0.41, "question-block-2.tres"], [0.55, "question-block-3.tres"]
	]:
		question.animation_player.seek(sample[0], true)
		assert(
			(
				question.sprite.texture.resource_path
				== "res://assets/palettes/underground/interactibles/blocks/" + sample[1]
			)
		)
	assert(question.receive_hit(EntityHit.new(null, &"bonk", Vector2.UP)))
	for frame in range(30):
		question.state_machine.process_physics(1.0 / 60.0)
	assert(question.state_machine.current_state.name == &"Inactive")
	assert(
		question.sprite.texture.resource_path.ends_with(
			"palettes/underground/interactibles/blocks/question-block-4.tres"
		)
	)
	var original_question := (
		load("res://scenes/entities/blocks/question/question_block.tscn").instantiate() as BaseBlock
	)
	add_child(original_question)
	original_question.animation_player.seek(0.55, true)
	assert(original_question.sprite.texture.resource_path.contains("/palettes/overworld/"))
	original_question.free()
	assert(lower.get_node("Camera2D").enabled)
	# Enter the painted coin's pickup area, then revisit it through real area loading.
	var pickups: Array[BasePlayer] = []
	lower_coin.connect("collected", func(player: BasePlayer): pickups.append(player))
	var player := level.player
	player.set_physics_process(false)
	player.body.global_position = lower_coin.global_position + Vector2(8, 16)
	player.body.velocity = Vector2.ZERO
	for frame in range(4):
		await get_tree().physics_frame
	assert(pickups == [player])
	assert(GameHandler.player_status.coins == 0 and GameHandler.player_status.score == 400)
	assert(GameHandler.player_status.lives == 3)
	assert(reward_voice.playing and reward_voice.stream == GameHandler._extra_life_one_shot)
	assert((reward_voice.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED)
	GameHandler.award_coin()
	assert(GameHandler.player_status.coins == 1 and GameHandler.player_status.score == 600)
	assert(GameHandler.player_status.lives == 3)
	assert(reward_voice.playing and reward_voice.stream == GameHandler._extra_life_one_shot)
	assert(lower_coin.state_machine.current_state.name == &"Collected")
	assert(not lower_coin.sprite.visible and not lower_coin.get_node("Pickup").monitoring)
	assert(not lower_coin.get_node("PaletteAnimation").enabled)
	assert(level.request_area_transfer(&"main", &"player_spawn"))
	await get_tree().process_frame
	assert(level.request_area_transfer(&"lower"))
	await get_tree().process_frame
	var restored_coin := lower.get_node("WorldObjects/coin_2_5") as BaseEntity
	assert(restored_coin.state_machine.current_state.name == &"Collected")
	assert(
		not restored_coin.sprite.visible and not restored_coin.get_node("PaletteAnimation").enabled
	)
	assert(GameHandler.player_status.coins == 1 and GameHandler.player_status.score == 600)
	assert(GameHandler.player_status.lives == 3)
	GameHandler.clear_session()
	assert(not reward_voice.playing)
	level.shutdown()
	for block in lower.get_node("WorldObjects").get_children():
		assert(block.is_shutdown)
	level.free()
	for frame in range(6):
		await get_tree().physics_frame
	print(
		"PASS: independent area themes, Underground terrain/decorations/pipes/question frames, artwork fallback, inherited bounce, resource isolation, and shutdown."
	)
	get_tree().quit()
