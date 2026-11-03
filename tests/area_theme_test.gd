extends Node


func _ready() -> void:
	var level := load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
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
	level = (ResourceLoader.load("res://.godot/validation/area-save-roundtrip.tscn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate() as BaseLevel
	for path: String in saved_cells:
		var parts := path.split("/")
		assert(level.get_node("Areas/" + parts[0] + "/Layouts/" + parts[1]).tile_map_data == saved_cells[path])
	assert(level.get_node("Areas/MainArea/Camera2D").enabled)
	assert(not level.get_node("Areas/LowerArea/Camera2D").enabled)
	add_child(level)
	var main := level.get_node("Areas/MainArea") as BaseLevelArea
	var lower := level.get_node("Areas/LowerArea") as BaseLevelArea
	assert(main.theme.display_name == "Overworld")
	assert(lower.theme.display_name == "Underground")
	var main_ground := main.get_node("Layouts/GroundLayout") as TileMapLayer
	assert(not lower.runtime_loaded and not lower.has_node("Layouts"))
	var main_terrain := main_ground.tile_set
	var main_decorations := main.theme.decorations
	assert(level.request_area_transfer(&"lower"))
	await get_tree().process_frame
	assert(lower.runtime_loaded and not main.runtime_loaded)
	var lower_ground := lower.get_node("Layouts/GroundLayout") as TileMapLayer
	assert(main_terrain != lower_ground.tile_set)
	assert((main_terrain.get_source(0) as TileSetAtlasSource).texture.resource_path.contains("Overworld"))
	assert((lower_ground.tile_set.get_source(0) as TileSetAtlasSource).texture.resource_path.contains("Underground"))
	for source_id in range(5):
		var source := lower_ground.tile_set.get_source(source_id) as TileSetAtlasSource
		assert(source.get_tile_data(Vector2i.ZERO,0).get_collision_polygons_count(0) == 1)
	# Missing pipe and decoration variants retain the original texture resources.
	assert((main_terrain.get_source(1) as TileSetAtlasSource).texture == (lower_ground.tile_set.get_source(1) as TileSetAtlasSource).texture)
	assert(main_decorations == lower.get_node("Layouts/DecorationLayout").tile_set)
	var originals := load("res://scenes/entities/blocks/brick/brick_block.tscn").instantiate() as BaseBlock
	var original_texture: Texture2D = originals.get_node("Sprite2D").texture
	originals.free()
	var underground_count := 0
	for block in lower.get_node("WorldObjects").get_children():
		assert(block.visual_theme == lower.theme)
		if block.sprite.texture.resource_path.contains("brick"):
			underground_count += 1
			assert(block.sprite.texture.resource_path.contains("Underground"))
			var texture: Texture2D = block.sprite.texture
			assert(block.receive_hit(EntityHit.new(null,&"bonk",Vector2.UP)))
			for frame in range(30):
				block.state_machine.process_physics(1.0/60.0)
			assert(block.sprite.texture == texture and block.state_machine.current_state.name == &"Active")
	assert(underground_count > 0)
	assert(original_texture.resource_path.contains("Overworld"))
	# Same painted IDs, different tile textures, and no shared resource mutation.
	assert(lower.theme.resolve_texture(original_texture).resource_path.contains("Underground"))
	assert(main.theme.resolve_texture(original_texture) == original_texture)
	assert(lower.get_node("Camera2D").enabled)
	level.shutdown()
	for block in lower.get_node("WorldObjects").get_children():
		assert(block.is_shutdown)
	level.free()
	print("PASS: independent area themes, Underground terrain/bricks, artwork fallback, inherited bounce, resource isolation, and shutdown.")
	get_tree().quit()
