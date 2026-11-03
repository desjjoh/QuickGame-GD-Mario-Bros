@tool
class_name BaseLevelArea
extends Node2D
## Owns area layouts, entities, camera, theme, and entry/exit music lifecycle.

var _runtime_templates: Dictionary[StringName, PackedScene] = {}
var runtime_loaded: bool = true
var is_active: bool = false
var _music_player: AudioStreamPlayer

@export var music_enabled: bool = true:
	set(value):
		if music_enabled == value:
			return
		music_enabled = value
		if is_active and not Engine.is_editor_hint():
			_start_music()

@export var area_id: StringName
@export var transport_points: Array[TransportPlacement] = []
var _transport_cells: Dictionary[Vector2i, StringName] = {}

@export var pipe_routes: Array[PipeRoute] = []
@export var theme: AreaTheme:
	set(value):
		theme = value
		if is_inside_tree():
			apply_theme()
			if is_active and not Engine.is_editor_hint():
				_start_music()


func _ready() -> void:
	apply_theme()


func enter_area() -> void:
	if Engine.is_editor_hint() or is_active or not runtime_loaded or not is_inside_tree():
		return
	is_active = true
	_start_music()


func exit_area() -> void:
	is_active = false
	_stop_music()


func _exit_tree() -> void:
	exit_area()


func _start_music() -> void:
	_stop_music()
	if not is_active or not music_enabled or theme == null or theme.music == null:
		return
	var stream := theme.music.duplicate() as AudioStream
	# Runtime copies leave source resources and their import settings untouched.
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = theme.music_loop
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.stream = stream
	_music_player.volume_db = theme.music_volume_db
	_music_player.finished.connect(_on_music_finished.bind(_music_player))
	add_child(_music_player)
	_music_player.play()


func _on_music_finished(audio: AudioStreamPlayer) -> void:
	# Fallback for stream formats without a native loop flag.
	if audio == _music_player and is_active and music_enabled and theme != null and theme.music_loop and is_instance_valid(_music_player):
		_music_player.play()


func _stop_music() -> void:
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.queue_free()
	_music_player = null


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


func configure_transport(entity: TransportEntity, cell: Vector2i) -> bool:
	var selected: TransportPlacement = null
	for point in transport_points:
		if point != null and point.cell == cell:
			if selected != null:
				push_error("Duplicate transport configuration at %s in area %s." % [cell, area_id])
				return false
			selected = point
	if entity is PipeEntrance and not configure_pipe_route(entity, cell):
		return false
	if selected != null:
		entity.transport_id = selected.target_id
		entity.destination = selected.destination
		entity.entrance_enabled = selected.entrance_enabled
		entity.exit_enabled = selected.exit_enabled
		entity.exit_distance = selected.exit_distance
	return true


func refresh_transport_cells() -> void:
	if not runtime_loaded or not has_node("Layouts/EntityLayout"):
		return
	_transport_cells.clear()
	var layer := get_node("Layouts/EntityLayout") as TileMapLayer
	for cell in layer.get_used_cells():
		var data := layer.get_cell_tile_data(cell)
		if data != null:
			_transport_cells[cell] = StringName(str(data.get_custom_data("entity_id")))


func resolve_transport_target(id: StringName) -> Object:
	if id == &"":
		return null
	var selected: Object = null
	var candidates: Array = []
	candidates.append_array(transport_points)
	candidates.append($Arrival)
	candidates.append_array($Endpoints.get_children())
	for candidate in candidates:
		var matches: bool = (candidate is TransportPlacement and candidate.target_id == id) or (candidate is AreaEndpoint and candidate.get_endpoint_id() == id)
		if matches:
			if selected != null:
				return null
			selected = candidate
	if selected is TransportPlacement:
		if not selected.exit_enabled:
			return null
		if runtime_loaded:
			var layer := get_node("Layouts/EntityLayout") as TileMapLayer
			if layer.get_cell_tile_data(selected.cell) == null:
				return null
		elif not _transport_cells.has(selected.cell):
			return null
	return selected


func transport_entity_name(point: TransportPlacement) -> String:
	return "%s_%s_%s" % [_transport_cells.get(point.cell, &""), point.cell.x, point.cell.y]


func find_transport_entity(id: StringName) -> TransportEntity:
	if not runtime_loaded:
		return null
	var selected: TransportEntity = null
	for child in $WorldObjects.get_children():
		if child is TransportEntity and child.transport_id == id:
			if selected != null:
				return null
			selected = child
	return selected


func prepare_runtime() -> void:
	refresh_transport_cells()
	if not _runtime_templates.is_empty():
		return
	# Capture authoring data before marker-generated entities are created.
	for child in get_children():
		if child == _music_player or child.is_queued_for_deletion() or child.name in [&"Arrival", &"Endpoints"]:
			continue
		var copy := child.duplicate()
		_set_branch_owner(copy, copy)
		var packed := PackedScene.new()
		assert(packed.pack(copy) == OK)
		_runtime_templates[child.name] = packed
		copy.free()


func _set_branch_owner(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_set_branch_owner(child, root)


func load_runtime(snapshot: Dictionary) -> void:
	prepare_runtime()
	if not runtime_loaded:
		for branch_name in _runtime_templates:
			add_child(_runtime_templates[branch_name].instantiate())
		runtime_loaded = true
	process_mode = Node.PROCESS_MODE_INHERIT
	show()
	apply_theme()
	var layouts: Dictionary = snapshot.get("layouts", {})
	for layer_name: String in layouts:
		var layer := get_node("Layouts/" + layer_name) as TileMapLayer
		layer.tile_map_data = layouts[layer_name]


func unload_runtime() -> void:
	exit_area()
	if not runtime_loaded:
		return
	prepare_runtime()
	refresh_transport_cells()
	_shutdown_branch(self)
	for branch_name in _runtime_templates:
		var branch := get_node_or_null(NodePath(branch_name))
		if branch != null:
			branch.free()
	runtime_loaded = false
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()


func _shutdown_branch(parent: Node) -> void:
	for child in parent.get_children():
		if child is BaseEntity:
			child.shutdown()
		_shutdown_branch(child)
