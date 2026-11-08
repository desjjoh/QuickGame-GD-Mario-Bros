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
var _rise_tween: Tween


func show_score(amount: int, world_position: Vector2) -> bool:
	if not SCORE_CELLS.has(amount):
		hide()
		return false
	_show_cell(SCORE_CELLS[amount], world_position)
	return true


func show_one_up(world_position: Vector2) -> void:
	_show_cell(ONE_UP_CELL, world_position)


## Opt-in standard motion. Callers still own all score, life, and sound rewards.
func rise_and_free(distance: float = 24.0, duration: float = 0.8) -> void:
	if _rise_tween != null and _rise_tween.is_valid():
		_rise_tween.kill()
	_rise_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_rise_tween.tween_property(self, "position:y", position.y - distance, duration)
	_rise_tween.tween_callback(queue_free)


func _show_cell(cell: Vector2i, world_position: Vector2) -> void:
	region_rect = Rect2(Vector2(cell * TILE_SIZE), Vector2(TILE_SIZE))
	global_position = world_position
	reset_physics_interpolation()
	show()
