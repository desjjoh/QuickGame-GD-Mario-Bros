@tool
extends Node2D
## Draws the authored ending positions while editing a castle stage.

const APPROACH_COLOR := Color(1.0, 0.67, 0.25)
const RESCUE_COLOR := Color(0.35, 0.9, 1.0)
const FALLOFF_COLOR := Color(1.0, 0.45, 0.63)

var _guide_lines: Array[Vector2] = []


func _ready() -> void:
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	# The area is a sibling of the presentation. Read its current transform as it is edited.
	var lines := _read_guide_lines()
	if lines != _guide_lines:
		_guide_lines = lines
		queue_redraw()


func _read_guide_lines() -> Array[Vector2]:
	var ending := get_parent()
	var areas := ending.get_node_or_null("../../Areas")
	if areas == null:
		return []
	var area_id: StringName = ending.get("area_id")
	for child in areas.get_children():
		var area := child as BaseLevelArea
		if area == null or area.area_id != area_id or not area.is_visible_in_tree():
			continue
		var camera := area.get_node_or_null("Camera2D") as LevelCamera
		if camera == null:
			return []
		var viewport_size := (
			Vector2(
				ProjectSettings.get_setting("display/window/size/viewport_width", 256),
				ProjectSettings.get_setting("display/window/size/viewport_height", 240)
			)
			/ camera.zoom
		)
		var top := area.to_local(camera.global_position).y - viewport_size.y / 2.0
		var bottom := top + viewport_size.y
		var approach: float = ending.get("approach_camera_left")
		var rescue: float = ending.get("rescue_camera_left")
		var cutoff: float = ending.get("boss_fall_cutoff_y")
		var lines: Array[Vector2] = [
			Vector2(approach, top),
			Vector2(approach, bottom),
			Vector2(rescue, top),
			Vector2(rescue, bottom),
			Vector2(approach, cutoff),
			Vector2(approach + viewport_size.x, cutoff),
		]
		for index in range(lines.size()):
			lines[index] = to_local(area.to_global(lines[index]))
		return lines
	return []


func _draw() -> void:
	if not Engine.is_editor_hint() or _guide_lines.is_empty():
		return
	_draw_guide(0, "Approach camera left", APPROACH_COLOR, Vector2(4, 24))
	_draw_guide(2, "Rescue camera left", RESCUE_COLOR, Vector2(4, 36))
	_draw_guide(4, "Bowser fall cutoff", FALLOFF_COLOR, Vector2(4, -4))


func _draw_guide(index: int, label: String, color: Color, label_offset: Vector2) -> void:
	var start := _guide_lines[index]
	draw_dashed_line(start, _guide_lines[index + 1], color, 1.0, 8.0)
	draw_string(
		ThemeDB.fallback_font, start + label_offset, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color
	)
