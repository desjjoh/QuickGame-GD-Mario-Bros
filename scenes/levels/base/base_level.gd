class_name BaseLevel
extends CanvasGroup

## Shared foundation for playable levels.

const AREA_CONTENT = preload("res://scenes/levels/base/level_area_content.gd")
const DRAW_ORDER = preload("res://scenes/components/presentation/draw_order.gd")
const SPAWN_REGISTRY = preload("res://scenes/levels/base/level_spawn_registry.gd")

enum CompletionMode { NORMAL, WARP }

signal completion_started
var completion_in_progress: bool = false
var ending_in_progress: bool = false
var completion_dispatched: bool = false
@export var ending_presentation: LevelEndingPresentation
var completion_mode: CompletionMode = CompletionMode.NORMAL

enum DeathReason { NORMAL, TIMEOUT }
enum EntryMode { STAGE_START, RESPAWN, HALFWAY_RESPAWN }

signal level_started
var has_started: bool = false
var timer_expired: bool:
	get:
		return level_timer.has_expired
var time_up_shown: bool = false
var death_reason: DeathReason = DeathReason.NORMAL
var death_restart_entry: EntryMode = EntryMode.RESPAWN
var entry_mode: EntryMode = EntryMode.STAGE_START

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
## Optional restart marker for deaths at or beyond the stage's halfway check.
@export var halfway_spawn: Marker2D

var death_in_progress: bool = false
var transition_in_progress: bool = false

@export_group("Spawning")
@export var player_scene: PackedScene
@export var player_start_configuration: Resource
@export var entity_scenes: Dictionary[StringName, PackedScene] = {}

@export_group("Screen Bounds")
@export var keep_player_on_screen: bool = true
@export_range(0.0, 64.0, 1.0) var horizontal_screen_inset: float = 7.0

var player: BasePlayer
var player_behind_world: bool = false
var player_presentation: Node
var is_shutdown: bool = false
var _reward_timers: Dictionary[int, WeakRef] = {}
var _spawned_areas: Dictionary[int, bool] = {}
var _progress_key: String
var _persistent_progress: bool = false
var _halfway_camera_left: float = INF
var active_area: BaseLevelArea
var active_endpoint: AreaEndpoint
var active_target_id: StringName = &""

@onready var player_spawn: Marker2D = $Players/PlayerSpawn
@onready var players: Node2D = $Players
@onready var death_sequence: LevelDeath = $Systems/LevelDeath
@onready var level_timer: LevelTimer = $Systems/LevelTimer
@onready var area_transport: AreaTransport = $Systems/AreaTransport
@onready var area_content: AREA_CONTENT = $Systems/LevelAreaContent
@onready var spawn_registry: SPAWN_REGISTRY = $Systems/LevelSpawnRegistry
var entity_layout: TileMapLayer:
	get:
		return get_node_or_null("Areas/MainArea/Layouts/EntityLayout") as TileMapLayer

var world_objects: Node2D:
	get:
		return get_node_or_null("Areas/MainArea/WorldObjects") as Node2D


## Finds the nearest level, including the starting node itself.
static func containing(node: Node) -> BaseLevel:
	while node != null and not node is BaseLevel:
		node = node.get_parent()
	return node as BaseLevel


## Opt in when gameplay contact is handled separately from terrain collision.
func ignore_player_body(body: PhysicsBody2D) -> void:
	if is_instance_valid(player):
		body.add_collision_exception_with(player.body)


func has_spawn_capacity(category: StringName) -> bool:
	return spawn_registry.has_capacity(category)


## Claim immediately before adding a new actor to the tree.
func try_claim_spawn_slot(category: StringName, actor: Node, replace_oldest := false) -> bool:
	if is_shutdown:
		return false
	return spawn_registry.try_claim(category, actor, replace_oldest)


func _ready() -> void:
	GameHandler.pause_controller.register_level(self)
	level_timer.expired.connect(_on_timer_expired)
	level_timer.hurry_started.connect(_on_hurry_started)
	death_sequence.presentation_finished.connect(_retire_death_player)
	death_sequence.finished.connect(_restart_after_death, CONNECT_DEFERRED)
	transition_in_progress = GameHandler.transitions.busy and GameHandler.current_level == self
	DRAW_ORDER.apply($Areas, DRAW_ORDER.WORLD)
	# Clamp the player body after actor physics.
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
	spawn_player(halfway_spawn if entry_mode == EntryMode.HALFWAY_RESPAWN else player_spawn)
	_record_active_area()
	var initial_camera := active_area.get_node("Camera2D") as LevelCamera
	# The main area camera can unload while Mario is in a side room.
	if initial_camera.halfway_check_enabled:
		_halfway_camera_left = initial_camera.halfway_camera_left
	initial_camera.enabled = true
	initial_camera.make_current()
	var camera := get_viewport().get_camera_2d() as LevelCamera
	if camera != null and is_instance_valid(player):
		if entry_mode == EntryMode.STAGE_START:
			camera.reset_target(player.body)
		else:
			camera.snap_to_arrival(player.body, LevelCamera.LEFT_ARRIVAL_SPRITE_X)
	if not is_shutdown:
		active_area.enter_area()
		if not is_instance_valid(GameHandler.current_game):
			initialize_actors(false)
			_create_standalone_shadow()


func _physics_process(_delta: float) -> void:
	if is_shutdown:
		return
	if transition_in_progress or completion_in_progress:
		return
	if death_in_progress:
		death_sequence.advance(_delta)
		return
	if is_instance_valid(player_presentation):
		return
	for id: int in _reward_timers.keys():
		var block := _reward_timers[id].get_ref() as QuestionBlock
		if not is_instance_valid(block) or block.is_shutdown:
			_reward_timers.erase(id)
		else:
			block.advance_reward_timer()
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
	initialize_actors(false)
	has_started = true
	level_timer.start(GameHandler.animation_clock.tick_count, timer_enabled)
	_play_area_music(level_timer.is_hurry)
	level_started.emit()
	return true


func initialize_actors(suspended: bool) -> void:
	if (
		is_shutdown
		or death_in_progress
		or completion_in_progress
		or not is_instance_valid(active_area)
	):
		return
	active_area.initialize_actors(suspended)


func register_reward_timer(block: QuestionBlock) -> void:
	_reward_timers[block.get_instance_id()] = weakref(block)


func _play_area_music(start_warning: bool = false) -> void:
	if (
		has_started
		and not is_shutdown
		and not death_in_progress
		and not completion_in_progress
		and GameHandler.current_level == self
		and GameHandler.flow == GameHandler.GameFlow.PLAYING
		and is_instance_valid(active_area)
	):
		var mario := player as Mario
		var starman := mario != null and mario.starman.uses_starman_music()
		var pace := MusicHandler.Pace.NORMAL
		if start_warning:
			pace = MusicHandler.Pace.WARNING
		elif level_timer.is_hurry:
			pace = MusicHandler.Pace.FAST
		MusicHandler.play_area(self, active_area.background_music, starman, pace)


func _on_hurry_started() -> void:
	MusicHandler.start_hurry(self)


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


func spawn_player(marker: Marker2D = null) -> BasePlayer:
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
	if player_start_configuration != null:
		player.configure_start(player_start_configuration)
	var spawn_marker := marker if is_instance_valid(marker) else player_spawn
	player.position = players.to_local(spawn_marker.global_position)
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
	if is_instance_valid(player_presentation):
		player_presentation.cancel()
	is_shutdown = true
	GameHandler.pause_controller.clear_for_level(self)
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
	BaseEntity.shutdown_descendants(self)
	if not _persistent_progress:
		GameHandler.forget_area_progress(_progress_key)


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


func _commit_area_arrival(
	area: BaseLevelArea, target_id: StringName, arrival: Dictionary, under_cover: bool
) -> bool:
	player.state_machine.stop(false)
	player.on_area_arrival(arrival.get("through_pipe", false))
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
	camera.snap_to_arrival(player.body, arrival.get("camera_sprite_x", -1.0))
	var previous_area := active_area
	active_area = area
	active_target_id = target_id
	active_endpoint = arrival["endpoint"]
	if previous_area != area:
		_unload_area(previous_area)
	area.enter_area()
	if not under_cover:
		initialize_actors(false)
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
	if is_instance_valid(player_presentation):
		player_presentation.cancel()
	if area.runtime_loaded and _spawned_areas.has(area.get_instance_id()):
		return
	var snapshot := GameHandler.get_area_progress(_progress_key, area.area_id)
	area.load_runtime(snapshot)
	area_content.populate(area, snapshot.get("entities", {}))
	_spawned_areas[area.get_instance_id()] = true


func _save_area(area: BaseLevelArea) -> void:
	GameHandler.store_area_progress(_progress_key, area.area_id, area_content.capture(area), self)


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
	if is_instance_valid(player_presentation):
		player_presentation.cancel()
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
	if is_instance_valid(player_presentation):
		player_presentation.cancel()
	death_reason = reason
	death_in_progress = true
	death_restart_entry = _select_death_restart_entry()
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


func _select_death_restart_entry() -> EntryMode:
	if not is_instance_valid(halfway_spawn):
		return EntryMode.RESPAWN
	var camera := get_viewport().get_camera_2d() as LevelCamera
	if camera != null:
		var half_width := camera.get_viewport_rect().size.x / (2.0 * camera.zoom.x)
		if camera.global_position.x - half_width >= _halfway_camera_left:
			return EntryMode.HALFWAY_RESPAWN
	return EntryMode.RESPAWN


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


func _create_standalone_shadow() -> void:
	var composer := SharedShadowComposer.new()
	composer.name = "ShadowComposer"
	$Systems.add_child(composer)
	# Render the compositor outside the level it captures; scene ownership stays intact.
	RenderingServer.canvas_item_set_parent(composer.get_canvas_item(), get_canvas())
	var screen := Control.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	composer.add_child(screen)
	composer.set_shadow_style(ShadowStyle.game_default())
	composer.configure(self, screen)
	composer.bind_level(self)
