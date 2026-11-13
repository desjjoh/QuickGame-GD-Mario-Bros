class_name CastleEndingPresentation
extends LevelEndingPresentation

enum Phase { APPROACH, HOLD, WALK, AT_RESCUE, FINISHED }

const COLLAPSE_INTERVAL := 4
const SKIP_HOLD_TICKS := 2  # The first walk update is tick 3 after axe contact.
const WALK_SPEED := 90.0  # $18 in the NES horizontal speed byte, or 1.5 px per tick.
const WALK_MODIFIER := &"castle_ending_walk"

@export var area_id: StringName = &"main"
## Path from the ending area to its placed CastleBridge.
@export_node_path("Node2D") var bridge_path := NodePath("WorldObjects/CastleBridge")
@export_node_path("Node2D") var rescue_path := NodePath("WorldObjects/CastleRescue")
## Optional path from the ending area to its boss actor.
@export_node_path("Node2D") var boss_path: NodePath
@export_node_path("Node2D") var lift_spawner_path: NodePath
@export var boss_fall_cutoff_y := 224.0
## Camera-left positions relative to the ending area.
@export var approach_camera_left := 0.0
@export var rescue_camera_left := 0.0

var phase := Phase.APPROACH
var _camera: LevelCamera
var _bridge: CastleBridge
var _player: BasePlayer
var _rescue: CastleRescue
var _hold_ticks := 0
var _boss: Bowser
var _first_collapse_tick := 0
var _walk_tick := 0
var _fall_cutoff_y := 0.0
var _scroll_ticks := 0
var _player_arrived := false
var _paused_animation := false
@onready var _collapse_shatter: AudioStreamPlayer = $CollapseShatter


func bind_area(area: BaseLevelArea) -> void:
	if area.area_id != area_id:
		return
	if is_instance_valid(_bridge) and _bridge.axe.touched.is_connected(_on_axe_touched):
		_bridge.axe.touched.disconnect(_on_axe_touched)
	_bridge = area.get_node_or_null(bridge_path) as CastleBridge
	_camera = area.get_node_or_null("Camera2D") as LevelCamera
	_rescue = area.get_node_or_null(rescue_path) as CastleRescue
	if _camera == null or _bridge == null or _rescue == null or _rescue.player_stop == null:
		push_error("Castle Ending requires an area camera, a bridge, and a rescue stop.")
		return
	_camera.scroll_stop_left = approach_camera_left
	_bridge.axe.touched.connect(_on_axe_touched)


func keeps_area_music_on_start() -> bool:
	return true


func _on_axe_touched(player: BasePlayer) -> void:
	var level := BaseLevel.containing(self)
	if level != null:
		level.begin_ending(self, player, _bridge.axe)


func start(level: BaseLevel, player: BasePlayer, source: BaseEntity) -> bool:
	if (
		phase != Phase.APPROACH
		or not is_instance_valid(_bridge)
		or source != _bridge.axe
		or player.scripted_motion_step.is_valid()
		or not is_instance_valid(_rescue)
		or not is_instance_valid(_rescue.player_stop)
		or not is_instance_valid(_camera)
		or not _camera.acquire_scroll_lock(self)
	):
		return false
	_player = player
	_player.on_level_end()
	_paused_animation = _player.animation_player != null and _player.animation_player.is_playing()
	if _paused_animation:
		_player.animation_player.pause()
	if _player is Mario:
		_player.form_controller.presentation_owned = true
	_player.body.velocity = Vector2.ZERO
	_player.scripted_motion_step = _advance
	_hold_ticks = 0
	var area := level.active_area
	_boss = area.get_node_or_null(boss_path) as Bowser if not boss_path.is_empty() else null
	_first_collapse_tick = 0
	_walk_tick = SKIP_HOLD_TICKS + 1
	if is_instance_valid(_boss) and not _boss.is_shutdown and not _boss.is_queued_for_deletion():
		if _boss.is_defeated():
			_boss.hide()
			_boss.queue_free()
		else:
			_first_collapse_tick = _boss.bridge_collapse_delay()
			_fall_cutoff_y = area.to_global(Vector2(0, boss_fall_cutoff_y)).y
			_walk_tick = 0
	if not lift_spawner_path.is_empty():
		var lift_spawner := area.get_node_or_null(lift_spawner_path) as BaseEntity
		if lift_spawner != null:
			lift_spawner.hide()
			BaseEntity.shutdown_descendants(lift_spawner)
			lift_spawner.shutdown()
			lift_spawner.queue_free()
	_scroll_ticks = 0
	_rescue.reset()
	_player_arrived = false
	phase = Phase.HOLD
	return true


func _advance(delta: float) -> void:
	if phase == Phase.AT_RESCUE:
		if _rescue.advance(GameHandler.player_character):
			phase = Phase.FINISHED
			_finish.call_deferred()
		return
	if phase == Phase.HOLD:
		_hold_ticks += 1
		if _walk_tick == 0:
			_advance_bridge(delta)
			return
		if _hold_ticks < _walk_tick:
			if _hold_ticks == _walk_tick - 2:
				MusicHandler.stop_area(BaseLevel.containing(self))
			return
		phase = Phase.WALK
		_release_player_pose()
		_camera.scroll_stop_left = rescue_camera_left
		_camera.release_scroll_lock(self)
		_player.motion_values.set_modifier(WALK_MODIFIER, {&"max_speed": WALK_SPEED}, 400)
		_player.body.velocity.x = WALK_SPEED
		MusicHandler.play_castle_clear(BaseLevel.containing(self))
	elif phase != Phase.WALK:
		return
	if not _player_arrived:
		_player.advance_scripted_walk(1.0, delta, false)
		if _player.body.global_position.x >= _rescue.player_stop.global_position.x:
			_player.body.global_position = _rescue.player_stop.global_position
			_player.body.velocity = Vector2.ZERO
			var states := _player.state_machine
			if states.current_state == states.initial_state:
				states.initial_state.apply_presentation()
			else:
				states.change_state(states.initial_state)
			_player_arrived = true
	# The reference alternates one- and two-pixel scroll steps during the walk.
	var camera_arrived := _camera.advance_scripted_scroll(1.0 + (_scroll_ticks & 1))
	_scroll_ticks += 1
	if camera_arrived and _player_arrived:
		phase = Phase.AT_RESCUE


func _advance_bridge(delta: float) -> void:
	if _bridge.collapse_complete:
		if not is_instance_valid(_boss) or _boss.advance_bridge_fall(delta, _fall_cutoff_y):
			MusicHandler.stop_area(BaseLevel.containing(self))
			_walk_tick = _hold_ticks + 2
		return
	var since_first := _hold_ticks - _first_collapse_tick
	if since_first < 0 or since_first % COLLAPSE_INTERVAL != 0:
		return
	if is_instance_valid(_boss):
		_boss.step_on_collapsing_bridge()
	# Axe contact already hides the axe. Its collapse entry still plays the cues.
	if since_first > 0:
		_bridge.collapse_next_piece()
		if _bridge.collapse_complete and is_instance_valid(_boss):
			_boss.begin_bridge_fall()
	_play_collapse_sound(_bridge.collapse_complete)


func _play_collapse_sound(final_piece := false) -> void:
	SoundHandler.play_reward(&"bowser_fall" if final_piece else &"fireworks")
	_collapse_shatter.stream = SoundHandler.get_sound(&"brick_shatter")
	_collapse_shatter.play()


func _finish() -> void:
	var level := BaseLevel.containing(self)
	if level != null:
		level.finish_ending(self)


func is_finished() -> bool:
	return phase == Phase.FINISHED


func cancel() -> void:
	if is_instance_valid(_camera):
		_camera.release_scroll_lock(self)
	if is_instance_valid(_player) and _player.scripted_motion_step == _advance:
		_player.motion_values.remove_modifier(WALK_MODIFIER)
		_release_player_pose()
		_player.scripted_motion_step = Callable()
		if phase == Phase.HOLD and _paused_animation and not _player.is_shutdown:
			_player.animation_player.play()
	if _first_collapse_tick > 0 and _hold_ticks >= _first_collapse_tick:
		_collapse_shatter.stop()
		SoundHandler.stop_reward(&"fireworks")
		SoundHandler.stop_reward(&"bowser_fall")
	_hold_ticks = 0
	_boss = null
	_first_collapse_tick = 0
	if phase in [Phase.WALK, Phase.AT_RESCUE, Phase.FINISHED]:
		var level := BaseLevel.containing(self)
		if level != null:
			MusicHandler.stop_area(level)
	if is_instance_valid(_rescue):
		_rescue.reset()
	_player = null
	phase = Phase.APPROACH


func _release_player_pose() -> void:
	if _player is Mario:
		_player.form_controller.presentation_owned = false
