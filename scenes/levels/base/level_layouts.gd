@tool
extends Node2D
## Terrain and entity placements share the same 16-pixel grid.

const CELL_SIZE := Vector2i(16, 16)


func _enter_tree() -> void:
	enforce_grid()


func _process(_delta: float) -> void:
	enforce_grid()


func enforce_grid() -> void:
	if transform != Transform2D.IDENTITY:
		transform = Transform2D.IDENTITY
	for child in get_children():
		if not child is TileMapLayer:
			continue
		var layer := child as TileMapLayer
		if layer.transform != Transform2D.IDENTITY:
			layer.transform = Transform2D.IDENTITY
		if layer.tile_set == null:
			continue
		var cell_size := CELL_SIZE
		if layer.tile_set.tile_size != cell_size:
			layer.tile_set.tile_size = cell_size
		if layer.tile_set.tile_shape != TileSet.TILE_SHAPE_SQUARE:
			layer.tile_set.tile_shape = TileSet.TILE_SHAPE_SQUARE
