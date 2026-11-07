@tool
class_name BaseLevelArea
extends Node2D

signal area_theme_changed(theme: AreaTheme)
## Owns area layouts, entities, camera, theme, and entry/exit lifecycle.

@export_group("Camera Activity")
## Modern hysteresis buffers; not exact NES enemy-specific thresholds.
@export_range(0.0, 512.0, 16.0) var activation_buffer: float = 64.0
@export_range(0.0, 512.0, 16.0) var deactivation_buffer: float = 96.0
var _activity_entities: Dictionary[int, WeakRef] = {}
var _spawners: Dictionary[int, WeakRef] = {}

var _runtime_templates: Dictionary[StringName, PackedScene] = {}
# Retain the authored policy even if a spawned entity is removed.
var entity_persistence: Dictionary[String, bool] = {}
var runtime_loaded: bool = true
var is_active: bool = false
@export var area_id: StringName
@export var background_music: MusicHandler.Track = MusicHandler.Track.OVERWORLD
@export var transport_points: Array[TransportPlacement] = []
@export var question_block_rewards: Dictionary[Vector2i, PackedScene] = {}
var _transport_cells: Dictionary[Vector2i, StringName] = {}

@export var pipe_routes: Array[PipeRoute] = []
@export var theme: AreaTheme:
	set(value):
		theme = value
		if is_inside_tree():
			apply_theme()
			area_theme_changed.emit(theme)


func _ready() -> void:
	apply_theme()
	process_physics_priority = 110
	set_physics_process(false)


func enter_area() -> void:
	if Engine.is_editor_hint() or is_active or not runtime_loaded or not is_inside_tree():
		return
	is_active = true
	set_physics_process(true)
	update_camera_activity()


func exit_area() -> void:
	is_active = false
	set_physics_process(false)
	for reference: WeakRef in _activity_entities.values():
		var entity := reference.get_ref() as BaseEntity
		if is_instance_valid(entity):
			entity.set_activity_suspended(true)


func _exit_tree() -> void:
	exit_area()


func apply_theme() -> void:
	if theme == null or not has_node("Layouts"):
		return
	var assignments := {
		"GroundLayout": theme.terrain,
		"DecorationLayout": theme.decorations,
		"EntityLayout": theme.entity_markers,
		"EnemyLayout": theme.enemy_markers
	}
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
				return null  # Duplicate IDs are ambiguous, never first-match wins.
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
		var matches: bool = (
			(candidate is TransportPlacement and candidate.target_id == id)
			or (candidate is AreaEndpoint and candidate.get_endpoint_id() == id)
		)
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
		if child.is_queued_for_deletion() or child.name in [&"Arrival", &"Endpoints"]:
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
	_activity_entities.clear()
	_spawners.clear()
	runtime_loaded = false
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()


func _shutdown_branch(parent: Node) -> void:
	for child in parent.get_children():
		if child is BaseEntity:
			child.shutdown()
		_shutdown_branch(child)


func register_activity_entity(entity: BaseEntity) -> void:
	# Players belong to the level, even if a custom scene nests one in an area.
	if entity is BasePlayer:
		return
	_activity_entities[entity.get_instance_id()] = weakref(entity)
	if is_active:
		entity.set_activity_suspended(
			not get_activity_region(false).intersects(entity.get_activity_rect())
		)


func register_spawner(spawner: Node2D) -> void:
	_spawners[spawner.get_instance_id()] = weakref(spawner)


func get_activity_region(sleep_region: bool) -> Rect2:
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return Rect2()
	var size := get_viewport_rect().size / camera.zoom
	var margin := (
		maxf(activation_buffer, deactivation_buffer) if sleep_region else activation_buffer
	)
	return Rect2(camera.global_position - size / 2.0, size).grow(margin)


func _physics_process(_delta: float) -> void:
	update_camera_activity()


func update_camera_activity() -> void:
	if Engine.is_editor_hint() or not is_active or not runtime_loaded:
		return
	var wake_region := get_activity_region(false)
	var sleep_region := get_activity_region(true)
	for id: int in _activity_entities.keys():
		var entity := _activity_entities[id].get_ref() as BaseEntity
		if not is_instance_valid(entity) or entity.is_shutdown:
			_activity_entities.erase(id)
			continue
		var bounds := entity.get_activity_rect()
		if entity is SpawnableEntity and not sleep_region.intersects(bounds):
			entity.remove_offscreen()
			continue
		var region := wake_region if entity.activity_suspended else sleep_region
		entity.set_activity_suspended(not region.intersects(bounds))
	# Existing actors retain their independent death/transition suspension.
	# Do not create fresh actors while the parent level is frozen (including title).
	var level := get_parent().get_parent() as BaseLevel
	if (
		level != null
		and (
			level.is_shutdown
			or level.death_in_progress
			or level.completion_in_progress
			or level.transition_in_progress
			or not level.is_physics_processing()
		)
	):
		return
	for id: int in _spawners.keys():
		var spawner := _spawners[id].get_ref() as Node2D
		if not is_instance_valid(spawner):
			_spawners.erase(id)
			continue
		spawner.update_activity(wake_region, sleep_region, theme)
