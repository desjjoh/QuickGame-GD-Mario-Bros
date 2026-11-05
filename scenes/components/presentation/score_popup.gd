extends Sprite2D
## Place under a world-space parent before setting the reward and position.

const TILE_SIZE := Vector2i(16, 8)
const SCORE_CELLS := {
	100: Vector2i(0, 0),
	200: Vector2i(0, 1),
	400: Vector2i(0, 2),
	500: Vector2i(0, 3),
	800: Vector2i(0, 4),
	1000: Vector2i(1, 0),
	2000: Vector2i(1, 1),
	4000: Vector2i(1, 2),
	5000: Vector2i(1, 3),
	8000: Vector2i(1, 4),
}
const ONE_UP_CELL := Vector2i(1, 5)


func show_score(amount: int, world_position: Vector2) -> bool:
	if not SCORE_CELLS.has(amount):
		hide()
		return false
	_show_cell(SCORE_CELLS[amount], world_position)
	return true


func show_one_up(world_position: Vector2) -> void:
	_show_cell(ONE_UP_CELL, world_position)


func _show_cell(cell: Vector2i, world_position: Vector2) -> void:
	region_rect = Rect2(Vector2(cell * TILE_SIZE), Vector2(TILE_SIZE))
	global_position = world_position
	reset_physics_interpolation()
	show()
