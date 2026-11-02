class_name BaseLevel
extends CanvasGroup
## Shared foundation for playable levels.

@export_group("Spawning")
@export var player_scene: PackedScene
@export var entity_scenes: Dictionary[StringName, PackedScene] = {}
@export_group("Screen Bounds")
@export var keep_player_on_screen: bool = true
@export_range(0.0, 64.0, 1.0) var horizontal_screen_inset: float = 7.0

var player: BasePlayer
var is_shutdown: bool = false
var _layout_spawned: bool = false
var active_area: BaseLevelArea
var active_endpoint: AreaEndpoint
var _pipe_input_locked: bool = false
var _transfer_pending: bool = false
var _pipe_state: PlayerPipeEnterState = null
var _pipe_trip: Dictionary = {}

@onready var player_spawn: Marker2D = $Players/PlayerSpawn
@onready var players: Node2D = $Players
@onready var entity_layout: TileMapLayer = $Areas/MainArea/Layouts/EntityLayout
@onready var world_objects: Node2D = $Areas/MainArea/WorldObjects


func _ready() -> void:
	# Keep gameplay in one CanvasGroup Z band, with players drawn last.
	move_child(players, get_child_count() - 1)
	move_child($ForegroundObjects, get_child_count() - 1)
	# Player state physics runs at priority 0; clamp its moving body afterward.
	process_physics_priority = 100
	# All level children are ready before the level's _ready() runs.
	spawn_layout_entities()
	spawn_player()
	active_area = $Areas/MainArea
	_record_active_area()
	var camera := get_viewport().get_camera_2d() as LevelCamera
	if camera != null and is_instance_valid(player):
		camera.reset_target(player.body)


func spawn_layout_entities() -> void:
	if is_shutdown or _layout_spawned:
		return
	_layout_spawned = true
	for area in $Areas.get_children():
		if area is BaseLevelArea:
			_spawn_area_entities(area)


func _spawn_area_entities(area: BaseLevelArea) -> void:
	var layout := area.get_node("Layouts/EntityLayout") as TileMapLayer
	var objects := area.get_node("WorldObjects") as Node2D
	# Markers remain editable in the scene, but only entities render at runtime.
	layout.hide()
	if layout.tile_set == null:
		return
	if layout.tile_set.get_custom_data_layer_by_name("entity_id") < 0:
		push_error("EntityLayout TileSet needs an entity_id custom-data layer.")
		return
	for cell: Vector2i in layout.get_used_cells():
		var data := layout.get_cell_tile_data(cell)
		if data == null:
			continue
		var entity_id := StringName(str(data.get_custom_data("entity_id")))
		var scene: PackedScene = entity_scenes.get(entity_id)
		if scene == null:
			push_error("EntityLayout cell %s has unmapped entity_id '%s'." % [cell, entity_id])
			continue
		var instance := scene.instantiate()
		if not instance is BaseEntity:
			push_error("EntityLayout scenes must inherit BaseEntity: %s" % entity_id)
			instance.free()
			continue
		if instance is PipeEntrance and not area.configure_pipe_route(instance, cell):
			instance.free()
			continue
		instance.visual_theme = area.theme
		instance.name = "%s_%s_%s" % [entity_id, cell.x, cell.y]
		# Block/entity marker origins are the top-left of each grid cell.
		var local_origin := layout.map_to_local(cell) - Vector2(layout.tile_set.tile_size) / 2.0
		instance.position = objects.to_local(layout.to_global(local_origin))
		objects.add_child(instance)


func _physics_process(_delta: float) -> void:
	if _pipe_state != null:
		if not _pipe_trip_valid() or player.state_machine.current_state != _pipe_state:
			_abort_pipe_entry(true)
		return # Freeze the source camera/bounds while descent is controlled.
	if ControllerHandler.input_down <= 0.5:
		_pipe_input_locked = false
	var camera := get_viewport().get_camera_2d() as LevelCamera
	if camera != null and is_instance_valid(player) and not player.is_shutdown:
		camera.follow_target(player.body)
	clamp_player_to_camera()


func clamp_player_to_camera() -> void:
	if is_shutdown or not keep_player_on_screen or not is_instance_valid(player) or not is_instance_valid(player.body):
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var center := camera.global_position.x if camera is LevelCamera else camera.get_screen_center_position().x
	var half_width := get_viewport_rect().size.x / camera.zoom.x / 2.0
	var inset := minf(horizontal_screen_inset, half_width)
	var player_position := player.body.global_position
	var left_edge := center - half_width + inset
	var right_edge := center + half_width - inset
	# Resolve the boundary like a wall: cancel motion into it, even if input
	# has already reversed. Preserve motion away from it and vertical speed.
	if (player_position.x <= left_edge and player.body.velocity.x < 0.0) or (player_position.x >= right_edge and player.body.velocity.x > 0.0):
		player.body.velocity.x = 0.0
	player_position.x = clampf(player_position.x, center - half_width + inset, center + half_width - inset)
	player.body.global_position = player_position


func spawn_player() -> BasePlayer:
	if is_shutdown:
		return null
	if is_instance_valid(player):
		return player
	if player_scene == null:
		return null

	var instance := player_scene.instantiate()
	if not instance is BasePlayer:
		push_error("The level's player scene must inherit BasePlayer.")
		instance.free()
		return null

	player = instance as BasePlayer
	player.position = players.to_local(player_spawn.global_position)
	players.add_child(player)
	player.reset_physics_interpolation()
	if GameHandler.current_level == self:
		GameHandler.current_player = player
	return player


func _exit_tree() -> void:
	shutdown()
	if GameHandler.current_level == self:
		GameHandler.current_level = null
		GameHandler.current_player = null


func shutdown() -> void:
	if is_shutdown:
		return
	is_shutdown = true
	_abort_pipe_entry(false)
	set_process(false)
	set_physics_process(false)
	_shutdown_entities(self)


func _shutdown_entities(parent: Node) -> void:
	for child in parent.get_children():
		if child is BaseEntity:
			child.shutdown()
		_shutdown_entities(child)


func request_area_transfer(destination_id: StringName, endpoint_id: StringName = &"arrival") -> bool:
	if is_shutdown or _transfer_pending or not is_instance_valid(player) or player.is_shutdown:
		return false
	var destination := _resolve_area(destination_id)
	if destination == null:
		return false
	var endpoint := destination.resolve_endpoint(endpoint_id)
	if endpoint == null:
		return false
	if destination == active_area and (endpoint == active_endpoint or endpoint_id == &"arrival"):
		return false
	_transfer_pending = true
	_complete_area_transfer.call_deferred(weakref(destination), weakref(endpoint), destination_id, endpoint_id)
	return true


func _complete_area_transfer(destination_ref: WeakRef, endpoint_ref: WeakRef, destination_id: StringName, endpoint_id: StringName) -> void:
	_transfer_pending = false
	var destination := destination_ref.get_ref() as BaseLevelArea
	var endpoint := endpoint_ref.get_ref() as AreaEndpoint
	if is_shutdown or not is_instance_valid(destination) or not is_instance_valid(player) or player.is_shutdown:
		return
	if _resolve_area(destination_id) != destination or not is_instance_valid(endpoint) or destination.resolve_endpoint(endpoint_id) != endpoint:
		return
	# Finish the physics callback before teleporting or changing cameras.
	player.state_machine.stop(false)
	player.body.velocity = Vector2.ZERO
	player.body.global_position = endpoint.global_position
	player.body.reset_physics_interpolation()
	for area in $Areas.get_children():
		if area is BaseLevelArea:
			area.get_node("Camera2D").enabled = area == destination
	var camera := destination.get_node("Camera2D") as LevelCamera
	camera.make_current()
	camera.snap_to_arrival(player.body)
	active_area = destination
	active_endpoint = endpoint
	_pipe_input_locked = true
	_record_active_area()
	player.state_machine.start()


func _record_active_area() -> void:
	if GameHandler.current_level == self and active_area != null:
		GameHandler.set_session_value(&"current_area_id", active_area.area_id)
		GameHandler.set_session_value(&"current_endpoint_id", active_endpoint.get_endpoint_id() if is_instance_valid(active_endpoint) else &"")


func can_enter_pipe() -> bool:
	return not is_shutdown and not _transfer_pending and not _pipe_input_locked


func _resolve_area(id: StringName) -> BaseLevelArea:
	var selected: BaseLevelArea = null
	for area in $Areas.get_children():
		if area is BaseLevelArea and area.area_id == id:
			if selected != null:
				return null
			selected = area
	return selected


func request_pipe_entry(pipe: PipeEntrance) -> bool:
	if not can_enter_pipe() or not is_instance_valid(player) or player.is_shutdown or not is_instance_valid(pipe) or pipe.is_shutdown:
		return false
	if not pipe.can_start_entry(player):
		return false
	if pipe.get_parent().get_parent() != active_area:
		return false
	var destination := _resolve_area(pipe.destination_area_id)
	if destination == null:
		return false
	var endpoint := destination.resolve_endpoint(pipe.destination_endpoint_id)
	if endpoint == null or (destination == active_area and (endpoint == active_endpoint or pipe.destination_endpoint_id == &"arrival")):
		return false
	var state := player.pipe_enter_state
	if state == null:
		return false
	_pipe_trip = {
		"source": weakref(pipe), "destination": weakref(destination), "endpoint": weakref(endpoint),
		"area_id": pipe.destination_area_id, "endpoint_id": pipe.destination_endpoint_id
	}
	_pipe_state = state
	_transfer_pending = true
	state.configure(pipe.to_global(Vector2(16, 0)))
	state.descent_finished.connect(_on_pipe_descent_finished)
	if not player.state_machine.change_state(state):
		_abort_pipe_entry(false)
		return false
	return true


func _pipe_trip_valid() -> bool:
	if _pipe_trip.is_empty() or not is_instance_valid(player) or player.is_shutdown:
		return false
	var source := (_pipe_trip["source"] as WeakRef).get_ref() as PipeEntrance
	var destination := (_pipe_trip["destination"] as WeakRef).get_ref() as BaseLevelArea
	var endpoint := (_pipe_trip["endpoint"] as WeakRef).get_ref() as AreaEndpoint
	return is_instance_valid(source) and not source.is_shutdown and is_instance_valid(destination) and is_instance_valid(endpoint) and _resolve_area(_pipe_trip["area_id"]) == destination and destination.resolve_endpoint(_pipe_trip["endpoint_id"]) == endpoint


func _on_pipe_descent_finished() -> void:
	_finish_pipe_entry.call_deferred()


func _finish_pipe_entry() -> void:
	if is_shutdown or _pipe_state == null:
		return
	if not _pipe_trip_valid() or player.state_machine.current_state != _pipe_state:
		_abort_pipe_entry(true)
		return
	var trip := _pipe_trip.duplicate()
	_pipe_state.commit_transfer()
	_disconnect_pipe_state()
	_complete_area_transfer(trip["destination"], trip["endpoint"], trip["area_id"], trip["endpoint_id"])


func _disconnect_pipe_state() -> void:
	if is_instance_valid(_pipe_state) and _pipe_state.descent_finished.is_connected(_on_pipe_descent_finished):
		_pipe_state.descent_finished.disconnect(_on_pipe_descent_finished)
	_pipe_state = null
	_pipe_trip.clear()


func _abort_pipe_entry(resume_player: bool) -> void:
	var state := _pipe_state
	_disconnect_pipe_state()
	if state == null:
		return
	_transfer_pending = false
	if resume_player:
		_pipe_input_locked = true
	if is_instance_valid(player) and player.state_machine.current_state == state:
		player.state_machine.stop(false)
		if resume_player and not is_shutdown and not player.is_shutdown:
			player.state_machine.start()
