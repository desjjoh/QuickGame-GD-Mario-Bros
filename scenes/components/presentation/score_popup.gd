extends Sprite2D
## Place under a world-space parent before setting the reward and position.

const TILE_SIZE := Vector2i(16, 8)
const DRAW_ORDER := preload("res://scenes/components/presentation/draw_order.gd")
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
const RISE_TICKS := 48
const MIN_SCREEN_TOP := 16.0

var _shown_ticks := 0
var _rise_started_tick := -1
var _intervals_remaining := 0


func _ready() -> void:
	DRAW_ORDER.apply(self, DRAW_ORDER.REWARD_EFFECT)
	set_physics_process(false)


func show_score(amount: int, world_position: Vector2) -> bool:
	if not SCORE_CELLS.has(amount):
		hide()
		return false
	_show_cell(SCORE_CELLS[amount], world_position)
	return true


func show_one_up(world_position: Vector2) -> void:
	_show_cell(ONE_UP_CELL, world_position)


## The supplied position is the first drawn position. Leave it in place for one tick.
func rise_and_free(defer_first_draw := false) -> void:
	_rise_started_tick = Engine.get_physics_frames()
	_shown_ticks = 0 if defer_first_draw else 1
	if defer_first_draw:
		hide()
	set_physics_process(true)


## Some rewards are cleared before the standard lifetime by the NES enemy timer.
func expire_after_intervals(interval_elapsed: Signal, intervals: int) -> void:
	_intervals_remaining = intervals
	interval_elapsed.connect(_on_interval_elapsed)


func _on_interval_elapsed() -> void:
	_intervals_remaining -= 1
	if _intervals_remaining == 0:
		_expire()


func _physics_process(_delta: float) -> void:
	if Engine.get_physics_frames() == _rise_started_tick:
		return
	if _shown_ticks == RISE_TICKS:
		_expire()
		return
	if _shown_ticks == 0:
		show()
	else:
		var screen_top := get_viewport().canvas_transform * to_global(get_rect().position)
		if screen_top.y > MIN_SCREEN_TOP:
			global_position.y -= 1.0
	_shown_ticks += 1


func _expire() -> void:
	hide()
	set_physics_process(false)
	queue_free()


func _show_cell(cell: Vector2i, world_position: Vector2) -> void:
	region_rect = Rect2(Vector2(cell * TILE_SIZE), Vector2(TILE_SIZE))
	global_position = world_position
	reset_physics_interpolation()
	show()
