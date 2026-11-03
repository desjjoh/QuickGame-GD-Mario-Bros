extends Node


func _ready() -> void:
	var level := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	level.player_scene = null
	level.get_node("Areas/MainArea").apply_theme()
	var layouts := level.get_node("Areas/MainArea/Layouts")
	var painted: Dictionary = {}
	for layer in layouts.get_children():
		painted[layer.name] = layer.tile_map_data.duplicate()
		layer.position = Vector2(5, 7)
		layer.rotation = 0.5
		layer.scale = Vector2(2, 3)
		layer.tile_set = layer.tile_set.duplicate()
		layer.tile_set.tile_size = Vector2i(24, 32)
		layer.tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	layouts.position = Vector2(11, 13)
	level.position = Vector2(32, 48)
	add_child(level)
	layouts.enforce_grid()
	assert(layouts.transform == Transform2D.IDENTITY)
	for layer in layouts.get_children():
		assert(layer.transform == Transform2D.IDENTITY)
		assert(layer.tile_set.tile_size == Vector2i(16, 16))
		assert(layer.tile_set.tile_shape == TileSet.TILE_SHAPE_SQUARE)
		assert(layer.tile_map_data == painted[layer.name], "Grid enforcement must preserve painted cells.")
		assert(layer.to_global(layer.map_to_local(Vector2i(2, 3))) == Vector2(72, 104))
	for entity in level.world_objects.get_children():
		assert(entity.position.x == snappedf(entity.position.x, 16))
		assert(entity.position.y == snappedf(entity.position.y, 16))
	level.free()
	var base: Node = load("res://scenes/levels/base/base_level.tscn").instantiate()
	assert(base.get_node("Areas/MainArea/Layouts/GroundLayout") is TileMapLayer)
	base.free()
	print("PASS: inherited layouts share a fixed grid, preserve cells, and align spawned entities.")
	get_tree().quit()
