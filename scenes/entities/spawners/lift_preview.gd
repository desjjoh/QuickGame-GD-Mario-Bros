@tool
extends RefCounted

const COLOR := Color(0.35, 0.85, 1.0, 0.75)
const SURFACE_COLOR := Color(0.35, 0.85, 1.0, 0.4)


static func draw_path(item: Node2D, start: Vector2, finish: Vector2, width: float) -> void:
	var center := Vector2(width / 2.0, 0)
	item.draw_line(start + center, finish + center, COLOR, 1.0)
	draw_surface(item, start, width)
	draw_surface(item, finish, width)


static func draw_surface(item: Node2D, origin: Vector2, width: float) -> void:
	item.draw_line(origin, origin + Vector2(width, 0), SURFACE_COLOR, 1.0)
