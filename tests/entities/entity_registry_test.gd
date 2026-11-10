extends Node


func _ready() -> void:
	var base := load("res://scenes/levels/base/base_level.tscn").instantiate() as BaseLevel
	var registry := base.entity_scenes
	assert(registry.has(&"green_koopa_spawner") and registry.has(&"castle"))
	for path in [
		"res://tests/fixtures/sandbox_level.tscn", "res://scenes/levels/worlds/world 1/1-1.tscn"
	]:
		var packed := load(path) as PackedScene
		var state := packed.get_state()
		for property in range(state.get_node_property_count(0)):
			assert(
				state.get_node_property_name(0, property) != &"entity_scenes",
				"Derived levels must inherit the shared registry."
			)
		var level := packed.instantiate() as BaseLevel
		assert(level.entity_scenes.keys() == registry.keys())
		for key: StringName in registry:
			assert(level.entity_scenes[key].resource_path == registry[key].resource_path)
		level.free()
	for name in ["overworld", "underground", "castle"]:
		var theme := load("res://assets/themes/%s.tres" % name) as AreaTheme
		for tiles: TileSet in [theme.entity_markers, theme.enemy_markers]:
			for index in range(tiles.get_source_count()):
				var atlas := tiles.get_source(tiles.get_source_id(index)) as TileSetAtlasSource
				for tile in range(atlas.get_tiles_count()):
					var data := atlas.get_tile_data(atlas.get_tile_id(tile), 0)
					var key := StringName(data.get_custom_data("entity_id"))
					assert(registry.has(key), "Unmapped palette marker: %s" % key)
	base.free()
	print("entity_registry_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())
