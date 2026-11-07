class_name BaseLevel
extends CanvasGroup

## Shared foundation for playable levels.

const SPAWN_LIMITS := {&"power_up": 1, &"enemy": 5}

enum CompletionMode { NORMAL, WARP }

signal completion_started
var completion_in_progress: bool = false
var ending_in_progress: bool = false
var completion_dispatched: bool = false
@export var ending_presentation: LevelEndingPresentation
var completion_mode: CompletionMode = CompletionMode.NORMAL

enum DeathReason { NORMAL, TIMEOUT }

signal level_started
var has_started: bool = false
var timer_expired: bool:
	get:
		return level_timer.has_expired
var time_up_shown: bool = false
var death_reason: DeathReason = DeathReason.NORMAL

signal death_started

@export_group("Stage Display")
@export var stage_label: String = "1-1"
@export_range(0, 999) var starting_time: int = 400
@export var timer_enabled: bool = true:
	set(value):
		timer_enabled = value
		if GameHandler.current_level == self:
			GameHandler.timer_enabled = value

@export_group("Death")
@export var fall_death_enabled: bool = true
@export_range(0.0, 128.0, 1.0) var fall_death_margin: float = 34.0
@export var death_sound: AudioStream
@export_range(0.0, 10.0, 0.1) var death_fallback_delay: float = 1.0
@export var death_presentation_timeout: float = 10.0

var death_in_progress: bool = false
var transition_in_progress: bool = false

@export_group("Spawning")
@export var player_scene: PackedScene
@export var entity_scenes: Dictionary[StringName, PackedScene] = {}

@export_group("Screen Bounds")
@export var keep_player_on_screen: bool = true
@export_range(0.0, 64.0, 1.0) var horizontal_screen_inset: float = 7.0

var player: BasePlayer
var is_shutdown: bool = false
var _spawned_areas: Dictionary[int, bool] = {}
var _live_spawns: Dictionary[StringName, Array] = {}
var _progress_key: String
var _persistent_progress: bool = false
var active_area: BaseLevelArea
var active_endpoint: AreaEndpoint
var active_target_id: StringName = &""

@onready var player_spawn: Marker2D = $Players/PlayerSpawn
@onready var players: Node2D = $Players
@onready var death_sequence: LevelDeath = $Systems/LevelDeath
@onready var level_timer: LevelTimer = $Systems/LevelTimer
@onready var area_transport: AreaTransport = $Systems/AreaTransport
var entity_layout: TileMapLayer:
	get:
		return get_node_or_null("Areas/MainArea/Layouts/EntityLayout") as TileMapLayer

var world_objects: Node2D:
	get:
		return get_node_or_null("Areas/MainArea/WorldObjects") as Node2D


func has_spawn_capacity(category: StringName) -> bool:
	return not SPAWN_LIMITS.has(category) or _live_spawns.get(category, []).size() < SPAWN_LIMITS[category]


## Claim immediately before adding a new actor to the tree.
func try_claim_spawn_slot(category: StringName, actor: Node, replace_oldest := false) -> bool:
	if is_shutdown:
		return false
	if SPAWN_LIMITS.has(category):
		var live: Array = _live_spawns.get_or_add(category, [])
		if live.size() >= SPAWN_LIMITS[category]:
			if not replace_oldest:
				return false
			var previous: Node = live.pop_front()
			previous.queue_free()
			if previous is CanvasItem:
				previous.hide()
		live.append(actor)
		actor.tree_exited.connect(_release_spawn_slot.bind(category, actor), CONNECT_ONE_SHOT)
	return true


func _release_spawn_slot(category: StringName, actor: Node) -> void:
	_live_spawns[category].erase(actor)


func _ready() -> void:
	level_timer.expired.connect(_on_timer_expired)
	death_sequence.presentation_finished.connect(_retire_death_player)
	death_sequence.finished.connect(_restart_after_death, CONNECT_DEFERRED)
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
	area.entity_persistence.clear()
	_spawn_layout_entities(area, area.get_node("Layouts/EntityLayout"), saved_entities)
	_spawn_layout_entities(area, area.get_node("Layouts/EnemyLayout"), {})


func _spawn_layout_entities(
	area: BaseLevelArea, layout: TileMapLayer, saved_entities: Dictionary
) -> void:
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
		var instance := scene.instantiate()
		if not instance is BaseEntity:
			push_error("EntityLayout scenes must inherit BaseEntity: %s" % entity_id)
			instance.free()
			continue
		area.entity_persistence[entity_name] = instance.persist_progress
		if not instance.persist_progress:
			progress = {}
		elif progress.get("removed", false):
			instance.free()
			continue
		if instance is TransportEntity and not area.configure_transport(instance, cell):
			instance.free()
			continue
		instance.visual_theme = area.theme
		if instance is QuestionBlock:
			instance.power_up_scene = area.question_block_rewards.get(cell)
		instance.name = entity_name
		instance.restore_area_state(progress.get("state", {}))
		# Block/entity marker origins are the top-left of each grid cell.
		var local_origin := layout.map_to_local(cell) - Vector2(layout.tile_set.tile_size) / 2.0
		instance.position = objects.to_local(layout.to_global(local_origin))
		objects.add_child(instance)
		if ending_presentation != null:
			ending_presentation.bind_entity(instance, cell, area)


func _physics_process(_delta: float) -> void:
	if is_shutdown:
		return
	if transition_in_progress or completion_in_progress:
		return
	if death_in_progress:
		death_sequence.advance(_delta)
		return
	if area_transport.advance():
		return  # Freeze camera/bounds during controlled transport.
	var camera := get_viewport().get_camera_2d() as LevelCamera
	if camera != null and is_instance_valid(player) and not player.is_shutdown:
		camera.follow_target(player.body)
	clamp_player_to_camera()
	_check_fall_death()
	_update_level_timer()


func on_level_start() -> bool:
	if (
		has_started
		or is_shutdown
		or death_in_progress
		or completion_in_progress
		or transition_in_progress
	):
		return false
	if GameHandler.current_level != self or GameHandler.flow != GameHandler.GameFlow.PLAYING:
		return false
	# load_level initialized the value once. Start only the local countdown phase.
	has_started = true
	level_timer.start(GameHandler.animation_clock.tick_count)
	_play_area_music()
	level_started.emit()
	return true


func _play_area_music() -> void:
	if (
		has_started
		and not is_shutdown
		and not death_in_progress
		and not completion_in_progress
		and GameHandler.current_level == self
		and GameHandler.flow == GameHandler.GameFlow.PLAYING
		and is_instance_valid(active_area)
	):
		MusicHandler.play_area(self, active_area.background_music)


func _update_level_timer() -> void:
	if (
		not has_started
		or not timer_enabled
		or is_shutdown
		or death_in_progress
		or completion_in_progress
		or transition_in_progress
		or area_transport.pending
	):
		return
	if (
		GameHandler.current_level != self
		or GameHandler.flow != GameHandler.GameFlow.PLAYING
		or not is_instance_valid(player)
		or player.is_dead
	):
		return
	level_timer.advance(GameHandler.animation_clock.tick_count)


func _on_timer_expired() -> void:
	on_death(player, true, DeathReason.TIMEOUT)


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
	MusicHandler.stop_area(self)
	if ending_presentation != null:
		ending_presentation.cancel()
	if ending_in_progress and not completion_dispatched:
		GameHandler.cancel_completion(self)
	GameHandler.transitions.cancel_for_level(self)
	death_sequence.cancel()
	area_transport.cancel(false)
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
	return area_transport.begin(traveler, destination, source, true)


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
	return area_transport.begin(
		player, TransportDestination.create(destination_id, endpoint_id), null, false
	)


func request_pipe_entry(pipe: PipeEntrance) -> bool:
	return is_instance_valid(pipe) and transport(player, pipe.get_destination(), pipe)


func _commit_area_arrival(
	area: BaseLevelArea, target_id: StringName, arrival: Dictionary, under_cover: bool
) -> bool:
	player.state_machine.stop(false)
	player.body.velocity = Vector2.ZERO
	player.jump_action.reset_falling_gravity()
	player.body.global_position = arrival["position"]
	player.face_direction(1.0)
	player.body.reset_physics_interpolation()
	for candidate in $Areas.get_children():
		if candidate is BaseLevelArea and candidate.runtime_loaded:
			candidate.get_node("Camera2D").enabled = candidate == area
	var camera := area.get_node("Camera2D") as LevelCamera
	camera.make_current()
	camera.snap_to_arrival(player.body)
	var previous_area := active_area
	active_area = area
	active_target_id = target_id
	active_endpoint = arrival["endpoint"]
	if previous_area != area:
		_unload_area(previous_area)
	area.enter_area()
	_record_active_area()
	if previous_area != area and not under_cover:
		_play_area_music()
	return not is_shutdown and is_instance_valid(player) and not player.is_shutdown


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
		and not completion_in_progress
		and not area_transport.pending
		and not area_transport.input_locked
	)


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
		if entity != null:
			if not entity.persist_progress:
				continue
		elif not area.entity_persistence.get(entity_name, false):
			continue
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


func _check_fall_death() -> void:
	if (
		not fall_death_enabled
		or death_in_progress
		or area_transport.pending
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


func on_complete(
	destination: PackedScene = null, mode: CompletionMode = CompletionMode.NORMAL
) -> bool:
	if (
		is_shutdown
		or death_in_progress
		or completion_in_progress
		or transition_in_progress
		or area_transport.pending
		or area_transport.has_active_state()
		or not is_instance_valid(player)
		or player.is_dead
		or player.is_shutdown
	):
		return false
	if GameHandler.current_level != self or GameHandler.flow != GameHandler.GameFlow.PLAYING:
		return false
	if mode == CompletionMode.WARP and destination == null:
		return false
	completion_mode = mode
	completion_in_progress = true
	var accepted := GameHandler.complete_level(self, destination)
	if not accepted and not is_shutdown:
		completion_in_progress = false
	return accepted


func begin_ending(
	presentation: LevelEndingPresentation, traveler: BasePlayer, source: BaseEntity
) -> bool:
	if (
		presentation != ending_presentation
		or presentation == null
		or traveler != player
		or not is_instance_valid(player)
		or player.is_dead
		or player.is_shutdown
		or is_shutdown
		or death_in_progress
		or completion_in_progress
		or transition_in_progress
		or area_transport.pending
		or area_transport.has_active_state()
	):
		return false
	completion_in_progress = true
	ending_in_progress = true
	completion_mode = CompletionMode.NORMAL
	if not GameHandler.claim_completion(self):
		completion_in_progress = false
		ending_in_progress = false
		return false
	if is_shutdown or GameHandler.current_level != self:
		return false
	if not presentation.start(self, player, source):
		cancel_ending()
		return false
	return true


func finish_ending(presentation: LevelEndingPresentation) -> bool:
	if (
		presentation != ending_presentation
		or not ending_in_progress
		or is_shutdown
		or not presentation.is_finished()
	):
		return false
	return GameHandler.complete_level(self)


func cancel_ending() -> void:
	if ending_presentation != null:
		ending_presentation.cancel()
	completion_in_progress = false
	ending_in_progress = false
	completion_dispatched = false
	if not is_shutdown and GameHandler.current_level == self:
		var respawned := not is_instance_valid(player)
		if respawned:
			spawn_player()
		var camera := get_viewport().get_camera_2d() as LevelCamera
		if camera != null and is_instance_valid(player):
			if respawned:
				camera.snap_to_arrival(player.body)
			else:
				camera.reset_target(player.body)
		GameHandler.cancel_completion(self)
		_play_area_music()


func notify_completion_started() -> void:
	# GameHandler calls this after claiming completion and before transitioning.
	MusicHandler.stop_area(self)
	completion_started.emit()


func on_death(
	victim: BasePlayer, present: bool = false, reason: DeathReason = DeathReason.NORMAL
) -> bool:
	if (
		is_shutdown
		or transition_in_progress
		or death_in_progress
		or completion_in_progress
		or area_transport.pending
		or not is_instance_valid(victim)
		or victim != player
		or victim.is_shutdown
	):
		return false
	death_reason = reason
	death_in_progress = true
	MusicHandler.stop_area(self)
	if reason == DeathReason.TIMEOUT:
		GameHandler.set_player_form(PlayerStatus.PowerupForm.SMALL)
	GameHandler.set_lives(GameHandler.player_status.lives - 1)
	# Status observers can synchronously replace/shut down this level.
	# The accepted death is charged once; never continue old-world cleanup afterward.
	if is_shutdown or not is_instance_valid(victim) or victim != player or victim.is_shutdown:
		return true
	death_sequence.begin(
		self, victim, present, death_sound, death_fallback_delay, death_presentation_timeout
	)
	if not is_shutdown:
		death_started.emit()
	return true


func _retire_death_player(victim: BasePlayer) -> void:
	if not death_in_progress or is_shutdown or victim != player:
		return
	if is_instance_valid(victim):
		victim.shutdown()
		victim.hide()
		if GameHandler.current_player == victim:
			GameHandler.current_player = null
		player = null
		victim.queue_free()


func _restart_after_death() -> void:
	if is_shutdown or not death_in_progress or GameHandler.current_level != self:
		return
	GameHandler.restart_after_death(self, _progress_key)
