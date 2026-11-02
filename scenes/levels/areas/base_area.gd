@tool
class_name BaseLevelArea
extends Node2D
## Owns one area's authoring layouts, world entities, camera, and visual theme.

@export var area_id: StringName
@export var pipe_routes: Array[PipeRoute] = []
@export var theme: AreaTheme:
	set(value):
		theme = value
		if is_inside_tree():
			apply_theme()


func _ready() -> void:
	apply_theme()


func apply_theme() -> void:
	if theme == null or not has_node("Layouts"):
		return
	var assignments := {"GroundLayout": theme.terrain, "DecorationLayout": theme.decorations, "EntityLayout": theme.entity_markers}
	for layer_name: String in assignments:
		var layer := get_node("Layouts/" + layer_name) as TileMapLayer
		if assignments[layer_name] != null:
			layer.tile_set = assignments[layer_name]
	get_node("Layouts").enforce_grid()


func resolve_endpoint(id: StringName) -> AreaEndpoint:
	var result: AreaEndpoint = null
	var candidates: Array[Node] = [$Arrival]
	candidates.append_array($Endpoints.get_children())
	for candidate in candidates:
		if candidate is AreaEndpoint and candidate.get_endpoint_id() == id:
			if result != null:
				return null # Duplicate IDs are ambiguous, never first-match wins.
			result = candidate
	return result


func configure_pipe_route(pipe: PipeEntrance, cell: Vector2i) -> bool:
	var selected: PipeRoute = null
	for route in pipe_routes:
		if route != null and route.cell == cell:
			if selected != null:
				push_error("Duplicate pipe routes at cell %s in area %s." % [cell, area_id])
				return false
			selected = route
	if selected != null:
		pipe.destination_area_id = selected.destination_area_id
		pipe.destination_endpoint_id = selected.destination_endpoint_id
	return true
