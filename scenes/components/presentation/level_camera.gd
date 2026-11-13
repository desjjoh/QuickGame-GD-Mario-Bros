@tool
class_name LevelCamera
extends Camera2D
## Called after player movement and before the level's screen-edge clamp.

const LEFT_ARRIVAL_SPRITE_X := 56.0  # NES alternate pipe entrance X ($38).

@export var follow_enabled: bool = true
## Horizontal camera limits measured from the parent area's origin.
@export var area_left: float = -128.0:
	set(value):
		area_left = value
		queue_redraw()

@export var area_right: float = 768.0:
	set(value):
		area_right = value
		queue_redraw()

@export var scroll_start: float = 80.0
@export var full_speed_start: float = 112.0
## Mario's body origin is 8 pixels right of the NES sprite's top-left origin.
@export var target_origin_offset: float = 8.0

@export_group("Halfway Restart")
@export var halfway_check_enabled: bool = false:
	set(value):
		halfway_check_enabled = value
		queue_redraw()
## Camera-left threshold measured from the main area's origin.
@export var halfway_camera_left: float = 0.0:
	set(value):
		halfway_camera_left = value
		queue_redraw()

@export_group("Editor Guides")
@export var draw_world_bounds: bool = true:
	set(value):
		draw_world_bounds = value
		queue_redraw()

var _target_x: float
var _previous_progress_x: float
var _has_target: bool = false
var _scroll_lock: WeakRef
var halfway_left_limit_active := false
## Temporary cap on the camera's left edge, measured from the area origin.
var scroll_stop_left := INF

var world_left: float:
	get:
		return _area_origin_x() + area_left
var world_right: float:
	get:
		return _area_origin_x() + area_right
var world_halfway_camera_left: float:
	get:
		return _area_origin_x() + halfway_camera_left
var scroll_left_limit: float:
	get:
		return maxf(world_left, world_halfway_camera_left) if halfway_left_limit_active else world_left


func _area_origin_x() -> float:
	var area := get_parent() as Node2D
	return area.global_position.x if area != null else 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var height := (
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 240))
		/ maxf(zoom.y, 0.001)
	)
	var top := global_position.y - height / 2.0
	var bottom := global_position.y + height / 2.0
	var font := ThemeDB.fallback_font
	if halfway_check_enabled:
		var halfway_x := world_halfway_camera_left
		var start := to_local(Vector2(halfway_x, top))
		var end := to_local(Vector2(halfway_x, bottom))
		var color := Color(1.0, 0.85, 0.25)
		draw_dashed_line(start, end, color, 1.0, 8.0)
		draw_string(
			font,
			start + Vector2(4.0, 25.0),
			"Halfway camera left: %s (area)" % halfway_camera_left,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			color
		)
	if not draw_world_bounds:
		return
	var origin_x := _area_origin_x()
	var edges := [area_left, area_right]
	var colors := [Color(0.25, 0.9, 0.65), Color(1.0, 0.55, 0.25)]
	for index in range(2):
		var edge_x: float = origin_x + edges[index]
		var start := to_local(Vector2(edge_x, top))
		var end := to_local(Vector2(edge_x, bottom))
		draw_line(start, end, colors[index], -1.0)
		var label := "Area %s: %s" % ["Left" if index == 0 else "Right", edges[index]]
		var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var text_offset := Vector2(4.0 if index == 0 else -text_width - 4.0, 12.0)
		draw_string(
			font, start + text_offset, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, colors[index]
		)


func reset_target(target: CharacterBody2D) -> void:
	_target_x = target.global_position.x - _correction_x(target)
	_previous_progress_x = _target_x
	_has_target = true
	reset_physics_interpolation()
	force_update_scroll()


func acquire_scroll_lock(lock_owner: Node) -> bool:
	if (
		_scroll_lock != null
		and is_instance_valid(_scroll_lock.get_ref())
		and _scroll_lock.get_ref() != lock_owner
	):
		return false
	_scroll_lock = weakref(lock_owner)
	return true


func release_scroll_lock(lock_owner: Node) -> void:
	if _scroll_lock != null and _scroll_lock.get_ref() == lock_owner:
		_scroll_lock = null


func is_scroll_locked() -> bool:
	return _scroll_lock != null and is_instance_valid(_scroll_lock.get_ref())


func advance_scripted_scroll(pixels: float) -> bool:
	var width := get_viewport_rect().size.x / zoom.x
	var left := global_position.x - width / 2.0
	var stop := _maximum_left(width)
	if left >= stop:
		return true
	var next_left := minf(left + pixels, stop)
	global_position.x = next_left + width / 2.0
	force_update_scroll()
	return next_left == stop


func _maximum_left(width: float) -> float:
	var area_max := minf(world_right - width, _area_origin_x() + scroll_stop_left)
	return maxf(scroll_left_limit, area_max)


func follow_target(target: CharacterBody2D) -> void:
	var mario := target.get_parent() as Mario
	follow_position(
		target.global_position.x,
		_correction_x(target),
		mario != null and mario.is_riding_horizontal_lift()
	)


func _correction_x(target: CharacterBody2D) -> float:
	var player := target.get_parent() as BasePlayer
	return player.camera_correction_x if player != null else 0.0


func follow_position(
	current_x: float, correction_x: float = 0.0, riding_horizontal_lift := false
) -> void:
	var progress_x := current_x - correction_x
	if not _has_target:
		_target_x = progress_x
		_previous_progress_x = progress_x
		_has_target = true
	# Forward carry can scroll again after the lift reverses from a leftward trip.
	var previous_x := _previous_progress_x if riding_horizontal_lift else _target_x
	_previous_progress_x = progress_x
	if not follow_enabled or is_scroll_locked():
		_target_x = progress_x
		return
	# Count new rightward territory once. Collision recovery can oscillate
	# around a wall by a fraction of a pixel; adding every positive half
	# of that oscillation would permanently ratchet this one-way camera.
	var advance := progress_x - previous_x
	if advance <= 0.0:
		return
	_target_x = maxf(_target_x, progress_x)
	var width := get_viewport_rect().size.x / zoom.x
	# Keep interpolated presentation coordinates out of physics feedback.
	var left := global_position.x - width / 2.0
	var screen_x := current_x - target_origin_offset - left
	if screen_x < scroll_start:
		return
	# Keep the reference's early catch-up zone without alternating integer
	# steps against a continuously moving player.
	if screen_x < full_speed_start:
		advance *= 0.5
	var next_left := clampf(left + advance, scroll_left_limit, _maximum_left(width))
	global_position.x = next_left + width / 2.0
	force_update_scroll()


func snap_to_arrival(target: CharacterBody2D, sprite_screen_x: float = -1.0) -> void:
	# Arrival at another endpoint explicitly resets right-only camera history.
	if follow_enabled:
		var width := get_viewport_rect().size.x / zoom.x
		var left := clampf(
			(
				target.global_position.x
				- target_origin_offset
				- (sprite_screen_x if sprite_screen_x >= 0 else full_speed_start)
			),
			scroll_left_limit,
			_maximum_left(width)
		)
		global_position.x = left + width / 2.0
	reset_target(target)


func snap_to_left_limit(target: CharacterBody2D) -> void:
	global_position.x = scroll_left_limit + get_viewport_rect().size.x / (2.0 * zoom.x)
	reset_target(target)
