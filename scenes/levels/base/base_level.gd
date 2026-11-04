class_name BaseLevel
extends CanvasGroup

const SOUND_MIX = preload("res://assets/audio/sound_effect_mix.tres")
## Shared foundation for playable levels.

signal death_started

@export_group("Stage Display")
@export var stage_label: String = "1-1"
@export_range(0, 999) var starting_time: int = 400

@export_group("Death")
@export var fall_death_enabled: bool = true
@export_range(0.0, 128.0, 1.0) var fall_death_margin: float = 34.0
@export var death_sound: AudioStream
@export_range(0.0, 10.0, 0.1) var death_fallback_delay: float = 1.0
@export var death_presentation_timeout: float = 10.0

var death_in_progress: bool = false
var transition_in_progress: bool = false
var _death_elapsed: float = 0.0
var _death_audio: AudioStreamPlayer
var _death_audio_done: bool = true
var _death_player_done: bool = false
var _death_restart_queued: bool = false

@export_group("Spawning")
@export var player_scene: PackedScene
@export var entity_scenes: Dictionary[StringName, PackedScene] = {}

@export_group("Screen Bounds")
@export var keep_player_on_screen: bool = true
@export_range(0.0, 64.0, 1.0) var horizontal_screen_inset: float = 7.0

var player: BasePlayer
var is_shutdown: bool = false
var _spawned_areas: Dictionary[int, bool] = {}
var _progress_key: String
var _persistent_progress: bool = false
var active_area: BaseLevelArea
var active_endpoint: AreaEndpoint
var active_target_id: StringName = &""
var _transport_input_locked: bool = false
var _transfer_pending: bool = false
var _players_draw_index: int = -1
var _transport_state: PlayerTransportState = null
var _transport_trip: Dictionary = {}
var _transport_exiting: bool = false
var _transport_phase: int = 0
var _transport_completion_callback: Callable

@onready var player_spawn: Marker2D = $Players/PlayerSpawn
@onready var players: Node2D = $Players
var entity_layout: TileMapLayer:
	get:
		return get_node_or_null("Areas/MainArea/Layouts/EntityLayout") as TileMapLayer

var world_objects: Node2D:
	get:
		return get_node_or_null("Areas/MainArea/WorldObjects") as Node2D


func _ready() -> void:
	transition_in_progress = GameHandler.transitions.busy and GameHandler.current_level == self
	# Keep gameplay in one CanvasGroup Z band, with players drawn last.
	move_child(players, get_child_count() - 1)
	# Player state physics runs at priority 0; clamp its moving body afterward.
	process_physics_priority = 100
	# All level children are ready before the level's _ready() runs.
	_persistent_progress = GameHandler.current_level == self and not scene_file_path.is_empty()
	_progress_key = scene_file_path if _persistent_progress else "runtime:%s" % get_instance_id()
	if GameHandler.current_level == self or not is_instance_valid(GameHandler.current_level):
		GameHandler.select_level_progress(_progress_key)
	active_area = $Areas/MainArea
	for area in $Areas.get_children():
		if area is BaseLevelArea:
			area.prepare_runtime()
			if area != active_area:
				area.unload_runtime()
	_load_area(active_area)
	spawn_player()
	_record_active_area()
	var initial_camera := active_area.get_node("Camera2D") as LevelCamera
	initial_camera.enabled = true
	initial_camera.make_current()
	var camera := get_viewport().get_camera_2d() as LevelCamera
	if camera != null and is_instance_valid(player):
		camera.reset_target(player.body)
	if not is_shutdown:
		active_area.enter_area()


func spawn_layout_entities() -> void:
	if is_shutdown or active_area == null or _spawned_areas.has(active_area.get_instance_id()):
		return
	_spawn_area_entities(active_area, {})
	_spawned_areas[active_area.get_instance_id()] = true


func _spawn_area_entities(area: BaseLevelArea, saved_entities: Dictionary) -> void:
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
		var entity_name := "%s_%s_%s" % [entity_id, cell.x, cell.y]
		var progress: Dictionary = saved_entities.get(entity_name, {})
		if progress.get("removed", false):
			continue
		var instance := scene.instantiate()
		if not instance is BaseEntity:
			push_error("EntityLayout scenes must inherit BaseEntity: %s" % entity_id)
			instance.free()
			continue
		if instance is TransportEntity and not area.configure_transport(instance, cell):
			instance.free()
			continue
		instance.visual_theme = area.theme
		instance.name = entity_name
		instance.restore_area_state(progress.get("state", {}))
		# Block/entity marker origins are the top-left of each grid cell.
		var local_origin := layout.map_to_local(cell) - Vector2(layout.tile_set.tile_size) / 2.0
		instance.position = objects.to_local(layout.to_global(local_origin))
		objects.add_child(instance)


func _physics_process(_delta: float) -> void:
	if is_shutdown:
		return
	if transition_in_progress:
		return
	if death_in_progress:
		_update_death(_delta)
		return
	if _transport_state != null:
		if not _transport_trip_valid() or player.state_machine.current_state != _transport_state:
			_abort_transport(true)
		return  # Freeze camera/bounds during controlled transport.
	if (
		ControllerHandler.input_down <= 0.5
		and ControllerHandler.input_up <= 0.5
		and ControllerHandler.input_left <= 0.5
		and ControllerHandler.input_right <= 0.5
	):
		_transport_input_locked = false
	var camera := get_viewport().get_camera_2d() as LevelCamera
	if camera != null and is_instance_valid(player) and not player.is_shutdown:
		camera.follow_target(player.body)
	clamp_player_to_camera()
	_check_fall_death()


func clamp_player_to_camera() -> void:
	if (
		is_shutdown
		or not keep_player_on_screen
		or not is_instance_valid(player)
		or not is_instance_valid(player.body)
	):
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var center := (
		camera.global_position.x if camera is LevelCamera else camera.get_screen_center_position().x
	)
	var half_width := get_viewport_rect().size.x / camera.zoom.x / 2.0
	var inset := minf(horizontal_screen_inset, half_width)
	var player_position := player.body.global_position
	var left_edge := center - half_width + inset
	var right_edge := center + half_width - inset
	# KeepOnscr clamps position but retains outward momentum while input
	# points back into the screen, allowing reversal friction to finish the skid.
	var direction := ControllerHandler.get_axis().x if player.can_read_controller_input() else 0.0
	if (
		(player_position.x <= left_edge and player.body.velocity.x < 0.0 and direction <= 0.0)
		or (player_position.x >= right_edge and player.body.velocity.x > 0.0 and direction >= 0.0)
	):
		player.body.velocity.x = 0.0
	player_position.x = clampf(
		player_position.x, center - half_width + inset, center + half_width - inset
	)
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
	GameHandler.transitions.cancel_for_level(self)
	if is_instance_valid(_death_audio):
		_death_audio.stop()
		_death_audio.queue_free()
		_death_audio = null
	_abort_transport(false)
	set_process(false)
	set_physics_process(false)
	if is_instance_valid(active_area):
		active_area.exit_area()
	if is_instance_valid(active_area) and active_area.runtime_loaded:
		_save_area(active_area)
	_shutdown_entities(self)
	if not _persistent_progress:
		GameHandler.forget_area_progress(_progress_key)


func _shutdown_entities(parent: Node) -> void:
	for child in parent.get_children():
		if child is BaseEntity:
			child.shutdown()
		_shutdown_entities(child)


func transport(
	traveler: BasePlayer, destination: TransportDestination, source: TransportEntity = null
) -> bool:
	return _begin_transport(traveler, destination, source, true)


func request_area_transfer(
	destination_id: StringName, endpoint_id: StringName = &"arrival"
) -> bool:
	# Compatibility: scripted placement keeps its immediate-arrival behavior.
	if (
		is_instance_valid(active_area)
		and destination_id == active_area.area_id
		and endpoint_id == &"arrival"
	):
		return false
	return _begin_transport(
		player, TransportDestination.create(destination_id, endpoint_id), null, false
	)


func request_pipe_entry(pipe: PipeEntrance) -> bool:
	return is_instance_valid(pipe) and transport(player, pipe.get_destination(), pipe)


func _resolve_area(id: StringName) -> BaseLevelArea:
	var selected: BaseLevelArea = null
	for area in $Areas.get_children():
		if area is BaseLevelArea and area.area_id == id:
			if selected != null:
				return null
			selected = area
	return selected


func _resolve_target(area: BaseLevelArea, id: StringName) -> Object:
	# Reserved main-area destination follows the real level spawn marker.
	if area == $Areas/MainArea and id == &"player_spawn":
		return player_spawn if is_instance_valid(player_spawn) else null
	var definition := area.resolve_transport_target(id)
	if definition is TransportPlacement:
		if area.runtime_loaded:
			var target := area.find_transport_entity(id)
			if target == null or target.is_shutdown or not target.exit_enabled:
				return null
		else:
			var progress := GameHandler.get_area_progress(_progress_key, area.area_id)
			var entity_state: Dictionary = progress.get("entities", {}).get(
				area.transport_entity_name(definition), {}
			)
			if entity_state.get("removed", false):
				return null
	return definition


func _begin_transport(
	traveler: BasePlayer,
	destination: TransportDestination,
	source: TransportEntity,
	animate_arrival: bool
) -> bool:
	if (
		is_shutdown
		or transition_in_progress
		or death_in_progress
		or _transfer_pending
		or not is_instance_valid(traveler)
		or traveler != player
		or traveler.is_shutdown
		or destination == null
	):
		return false
	if destination.area_id == &"" or destination.target_id == &"":
		return false
	var area := _resolve_area(destination.area_id)
	if area == null:
		return false
	var definition := _resolve_target(area, destination.target_id)
	if definition == null or (area == active_area and destination.target_id == active_target_id):
		return false
	var state: PlayerTransportState = null
	if source != null:
		if (
			not is_instance_valid(source)
			or not source.is_inside_tree()
			or not can_transport()
			or source.get_parent().get_parent() != active_area
			or not source.can_start_transport(traveler)
		):
			return false
		state = source.get_transport_state(traveler)
		if state == null:
			return false
	_transport_trip = {
		"area": weakref(area),
		"definition": weakref(definition),
		"area_id": destination.area_id,
		"target_id": destination.target_id,
		"source": weakref(source) if source != null else null,
		"animate": animate_arrival
	}
	_transfer_pending = true
	_transport_phase += 1
	if source == null:
		_finish_transport.call_deferred(_transport_phase)
	else:
		state.configure(source.entry_position(), source.entry_direction())
		_start_transport_state(state)
	return _transfer_pending


func _start_transport_state(state: PlayerTransportState) -> void:
	_transport_state = state
	_transport_phase += 1
	_transport_completion_callback = _on_transport_finished.bind(_transport_phase)
	state.travel_finished.connect(_transport_completion_callback)
	state.exited.connect(_restore_player_draw_order)
	_players_draw_index = players.get_index()
	move_child(players, $Areas.get_index())
	var suspended := player.state_machine.gameplay_suspended
	player.state_machine.gameplay_suspended = false
	var changed := player.state_machine.change_state(state)
	player.state_machine.gameplay_suspended = suspended
	if not changed:
		_abort_transport(true)


func _transport_trip_valid() -> bool:
	if _transport_trip.is_empty() or not is_instance_valid(player) or player.is_shutdown:
		return false
	var area := (_transport_trip["area"] as WeakRef).get_ref() as BaseLevelArea
	var definition: Object = (_transport_trip["definition"] as WeakRef).get_ref()
	if (
		not is_instance_valid(area)
		or not is_instance_valid(definition)
		or _resolve_area(_transport_trip["area_id"]) != area
		or _resolve_target(area, _transport_trip["target_id"]) != definition
	):
		return false
	if not _transport_exiting and _transport_trip["source"] != null:
		var source := (_transport_trip["source"] as WeakRef).get_ref() as TransportEntity
		return is_instance_valid(source) and not source.is_shutdown
	return true


func _arrival_data(area: BaseLevelArea, target_id: StringName, animate: bool) -> Dictionary:
	var definition := _resolve_target(area, target_id)
	if definition == player_spawn:
		return {
			"position": player_spawn.global_position,
			"direction": Vector2.ZERO,
			"distance": 0.0,
			"state": null,
			"endpoint": null
		}
	if definition is TransportPlacement:
		var target := area.find_transport_entity(target_id)
		if target == null:
			return {}
		var state := target.get_transport_state(player)
		if animate and state == null:
			return {}
		return {
			"position": target.exit_position(),
			"direction": target.exit_direction(),
			"distance": target.exit_distance,
			"state": state if animate else null,
			"endpoint": null
		}
	if definition is AreaEndpoint:
		# Existing standalone spawns remain valid; animated legacy markers adapt to pipe presentation.
		return {
			"position": definition.global_position,
			"direction": definition.get_exit_vector(),
			"distance": definition.exit_distance,
			"state": player.pipe_enter_state if animate and definition.animate_exit else null,
			"endpoint": definition
		}
	return {}


func _on_transport_finished(phase: int) -> void:
	_finish_transport.call_deferred(phase)


func _finish_transport(phase: int) -> void:
	if phase != _transport_phase or is_shutdown or not _transfer_pending:
		return
	if not _transport_exiting and GameHandler.transitions.available():
		if (
			GameHandler.transitions.begin(
				self,
				_commit_transport_under_cover.bind(phase),
				&"area",
				_area_transition_complete,
				_area_transition_valid
			)
			== 0
		):
			_abort_transport(true)
		return
	_commit_transport(phase)


func _commit_transport_under_cover(phase: int) -> bool:
	if phase != _transport_phase or is_shutdown or GameHandler.current_level != self:
		return false
	if not _transport_trip_valid():
		return false
	_commit_transport(phase)
	return not is_shutdown and GameHandler.current_level == self


func _area_transition_valid() -> bool:
	return (
		not is_shutdown
		and GameHandler.current_level == self
		and (not _transfer_pending or _transport_trip_valid())
	)


func _area_transition_complete(success: bool) -> void:
	if not success and not is_shutdown:
		_abort_transport(true)


func _start_player_state() -> void:
	var suspended := player.state_machine.gameplay_suspended
	player.state_machine.gameplay_suspended = false
	player.state_machine.start()
	player.state_machine.gameplay_suspended = suspended


func _commit_transport(phase: int) -> void:
	if phase != _transport_phase or is_shutdown or not _transfer_pending:
		return
	if (
		not _transport_trip_valid()
		or (_transport_state != null and player.state_machine.current_state != _transport_state)
	):
		_abort_transport(true)
		return
	if _transport_exiting:
		_transport_state.commit_transfer()
		_disconnect_transport_state()
		_transfer_pending = false
		player.state_machine.stop(false)
		_start_player_state()
		return
	var trip := _transport_trip.duplicate()
	var area := (trip["area"] as WeakRef).get_ref() as BaseLevelArea
	var was_loaded := area.runtime_loaded
	_load_area(area)
	var arrival := _arrival_data(area, trip["target_id"], trip["animate"])
	if arrival.is_empty():
		if not was_loaded:
			_unload_area(area)
		_abort_transport(true)
		return
	if _transport_state != null:
		_transport_state.commit_transfer()
	_disconnect_transport_state()
	player.state_machine.stop(false)
	player.body.velocity = Vector2.ZERO
	player.body.global_position = arrival["position"]
	player.body.reset_physics_interpolation()
	for candidate in $Areas.get_children():
		if candidate is BaseLevelArea and candidate.runtime_loaded:
			candidate.get_node("Camera2D").enabled = candidate == area
	var camera := area.get_node("Camera2D") as LevelCamera
	camera.make_current()
	camera.snap_to_arrival(player.body)
	var previous_area := active_area
	active_area = area
	active_target_id = trip["target_id"]
	active_endpoint = arrival["endpoint"]
	if previous_area != area:
		_unload_area(previous_area)
	area.enter_area()
	_transport_input_locked = true
	_record_active_area()
	if is_shutdown or not is_instance_valid(player) or player.is_shutdown:
		_abort_transport(false)
		return
	var arrival_state := arrival["state"] as PlayerTransportState
	if arrival_state != null:
		_transport_trip = trip
		_transport_trip["source"] = null
		_transport_exiting = true
		arrival_state.configure(
			arrival["position"], arrival["direction"], true, arrival["distance"]
		)
		_start_transport_state(arrival_state)
	else:
		_transfer_pending = false
		_start_player_state()


func _record_active_area() -> void:
	if GameHandler.current_level != self or is_shutdown or not is_instance_valid(active_area):
		return
	var keys: Array[StringName] = [&"current_area_id", &"current_target_id", &"current_endpoint_id"]
	var values: Array = [active_area.area_id, active_target_id, active_target_id]
	for index in range(keys.size()):
		# Session observers may replace/shut down the level synchronously.
		if GameHandler.current_level != self or is_shutdown:
			return
		GameHandler.set_session_value(keys[index], values[index])


func can_enter_pipe() -> bool:
	return can_transport()


func can_transport() -> bool:
	return (
		not is_shutdown
		and not transition_in_progress
		and not death_in_progress
		and not _transfer_pending
		and not _transport_input_locked
	)


func _disconnect_transport_state() -> void:
	# Invalidate queued notifications before another phase/request can begin.
	_transport_phase += 1
	_restore_player_draw_order()
	if is_instance_valid(_transport_state):
		if _transport_state.exited.is_connected(_restore_player_draw_order):
			_transport_state.exited.disconnect(_restore_player_draw_order)
		if (
			_transport_completion_callback.is_valid()
			and _transport_state.travel_finished.is_connected(_transport_completion_callback)
		):
			_transport_state.travel_finished.disconnect(_transport_completion_callback)
	_transport_state = null
	_transport_completion_callback = Callable()
	_transport_trip.clear()
	_transport_exiting = false


func _abort_transport(resume_player: bool) -> void:
	var state := _transport_state
	_disconnect_transport_state()
	_transfer_pending = false
	if state == null:
		return
	if resume_player:
		_transport_input_locked = true
	if is_instance_valid(player) and player.state_machine.current_state == state:
		player.state_machine.stop(false)
		if resume_player and not is_shutdown and not player.is_shutdown:
			_start_player_state()


func _load_area(area: BaseLevelArea) -> void:
	if area.runtime_loaded and _spawned_areas.has(area.get_instance_id()):
		return
	var snapshot := GameHandler.get_area_progress(_progress_key, area.area_id)
	area.load_runtime(snapshot)
	_spawn_area_entities(area, snapshot.get("entities", {}))
	_spawned_areas[area.get_instance_id()] = true


func _save_area(area: BaseLevelArea) -> void:
	var layouts: Dictionary = {}
	for layer in area.get_node("Layouts").get_children():
		if layer is TileMapLayer:
			layouts[str(layer.name)] = layer.tile_map_data.duplicate()
	var entities: Dictionary = {}
	var markers := area.get_node("Layouts/EntityLayout") as TileMapLayer
	var objects := area.get_node("WorldObjects") as Node2D
	for cell: Vector2i in markers.get_used_cells():
		var data := markers.get_cell_tile_data(cell)
		if data == null:
			continue
		var id := StringName(str(data.get_custom_data("entity_id")))
		var entity_name := "%s_%s_%s" % [id, cell.x, cell.y]
		var entity := objects.get_node_or_null(NodePath(entity_name)) as BaseEntity
		entities[entity_name] = {
			"removed": entity == null,
			"state": entity.capture_area_state() if entity != null else {}
		}
	GameHandler.store_area_progress(
		_progress_key, area.area_id, {"layouts": layouts, "entities": entities}, self
	)


func _unload_area(area: BaseLevelArea) -> void:
	if area == null or not area.runtime_loaded:
		return
	_save_area(area)
	area.unload_runtime()
	_spawned_areas.erase(area.get_instance_id())


func _restore_player_draw_order() -> void:
	if _players_draw_index < 0:
		return
	var original_index := _players_draw_index
	_players_draw_index = -1
	# Do not reorder siblings while a dying player/level exits the tree.
	if is_shutdown or not is_instance_valid(player) or player.is_shutdown:
		return
	if is_instance_valid(players) and players.get_parent() == self:
		move_child(players, mini(original_index, get_child_count() - 1))


func _check_fall_death() -> void:
	if (
		not fall_death_enabled
		or death_in_progress
		or _transfer_pending
		or not is_instance_valid(player)
		or player.is_shutdown
	):
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var center_y := (
		camera.global_position.y if camera is LevelCamera else camera.get_screen_center_position().y
	)
	var bottom := center_y + get_viewport_rect().size.y / camera.zoom.y / 2.0
	if player.death_envelope_top() > bottom + fall_death_margin:
		on_death(player, false)


func on_death(victim: BasePlayer, present: bool = false) -> bool:
	if (
		is_shutdown
		or transition_in_progress
		or death_in_progress
		or _transfer_pending
		or not is_instance_valid(victim)
		or victim != player
		or victim.is_shutdown
	):
		return false
	death_in_progress = true
	GameHandler.set_lives(GameHandler.player_status.lives - 1)
	# Status observers can synchronously replace/shut down this level.
	# The accepted death is charged once; never continue old-world cleanup afterward.
	if is_shutdown or not is_instance_valid(victim) or victim != player or victim.is_shutdown:
		return true
	_death_elapsed = 0.0
	# Suspend gameplay callbacks and physics without pausing AnimationPlayers.
	for entity in find_children("*", "BaseEntity", true, false):
		if entity != player:
			(entity as BaseEntity).set_gameplay_suspended(true)
	_start_death_audio()
	player.death_presentation_finished.connect(_on_death_player_finished, CONNECT_ONE_SHOT)
	player.begin_death(present)
	if not is_shutdown:
		death_started.emit()
	return true


func _on_death_player_finished() -> void:
	if not death_in_progress or is_shutdown:
		return
	_death_player_done = true
	if is_instance_valid(player):
		var victim := player
		victim.shutdown()
		victim.hide()
		if GameHandler.current_player == victim:
			GameHandler.current_player = null
		player = null
		victim.queue_free()


func _start_death_audio() -> void:
	_death_audio_done = death_sound == null
	if death_sound == null:
		return
	var stream := death_sound.duplicate() as AudioStream
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = false
	_death_audio = AudioStreamPlayer.new()
	_death_audio.stream = stream
	_death_audio.volume_db = SOUND_MIX.volume_for(death_sound)
	add_child(_death_audio)
	_death_audio.finished.connect(func(): _death_audio_done = true)
	_death_audio.play()


func _update_death(delta: float) -> void:
	_death_elapsed += delta
	var audio_limit := maxf(
		death_fallback_delay,
		death_sound.get_length() + 1.0 if death_sound != null else death_fallback_delay
	)
	if _death_elapsed >= maxf(death_presentation_timeout, audio_limit):
		_on_death_player_finished()
		_death_audio_done = true
	if not _death_player_done and not is_instance_valid(player):
		_death_player_done = true
	if (
		_death_player_done
		and (_death_audio_done or _death_elapsed >= audio_limit)
		and (death_sound != null or _death_elapsed >= death_fallback_delay)
	):
		if not _death_restart_queued:
			_death_restart_queued = true
			_restart_after_death.call_deferred()


func _restart_after_death() -> void:
	if is_shutdown or not death_in_progress or GameHandler.current_level != self:
		return
	GameHandler.restart_after_death(self, _progress_key)
