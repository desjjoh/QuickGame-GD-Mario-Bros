class_name FlagpoleEndingPresentation
extends LevelEndingPresentation

const SCORE_POPUP = preload("res://scenes/components/presentation/score_popup.tscn")
enum Phase { IDLE, DESCEND, DISMOUNT, WALK, SCORE, FIREWORKS, WAIT, FINISHED, RAISE_FLAG }
signal phase_changed(phase: Phase)

@export var area_id: StringName = &"main"
@export var flagpole_cell: Vector2i
@export var castle_cell: Vector2i
@export var flag_sound: AudioStream
@export var flag_sound_cue: StringName
@export var music: AudioStream
@export var music_pulse: AudioStream
@export var post_delay_frames: int = 126
@onready var score_step: EndingStep = $Score
@onready var fireworks_step: EndingStep = $Fireworks

var phase: Phase = Phase.IDLE
var active: bool = false
var grab_height: float = 0.0
var grab_points: int = 0
var _score_popup: Sprite2D
var _popup_fraction: int = 255
var remaining_time_at_contact: int = 0
var _level: BaseLevel
var _player: BasePlayer
var _pole: FlagpoleEntity
var _castle: CastleEntity
var _camera: LevelCamera
var _descent_stop_y: float
var _walk_endpoint: Vector2
var _dismount_ticks: int
var _audio: AudioStreamPlayer
var _pulse_audio: AudioStreamPlayer
var _wait_frames: int = 0
var _generation: int = 0
var _previous_climb_controls: bool = true
var _music_started: bool = false
var _music_ticks: int = 0
var _music_limit: int = 0


func _ready() -> void:
	SoundHandler.reward_voice_changed.connect(_set_reward_voice_occupied)
	if flag_sound == null:
		flag_sound = SoundHandler.get_sound(flag_sound_cue)
	process_physics_priority = 50
	set_physics_process(false)
	score_step.finished.connect(_on_score_finished)
	fireworks_step.finished.connect(_on_fireworks_finished)


func bind_entity(entity: BaseEntity, cell: Vector2i, area: BaseLevelArea) -> void:
	if area.area_id != area_id:
		return
	if entity is FlagpoleEntity and cell == flagpole_cell:
		entity.player_attached.connect(_on_attached.bind(entity))
	elif entity is CastleEntity and cell == castle_cell:
		_castle = entity


func _on_attached(player: BasePlayer, pole: FlagpoleEntity) -> void:
	if active:
		return
	var level := BaseLevel.containing(self)
	if level != null and is_instance_valid(_castle) and not _castle.is_shutdown:
		level.begin_ending(self, player, pole)


func start(level: BaseLevel, player: BasePlayer, source: BaseEntity) -> bool:
	if (
		active
		or not source is FlagpoleEntity
		or not is_instance_valid(_castle)
		or _castle.is_shutdown
		or player.climb_state == null
		or player.climb_state.move_state == null
		or player.scripted_motion_step.is_valid()
	):
		return false
	_level = level
	_player = player
	_pole = source as FlagpoleEntity
	_pole.reset_flag()
	grab_height = maxf(0.0, _pole.climb_bottom.global_position.y - player.body.global_position.y)
	grab_points = points_for_grab_height(grab_height)
	remaining_time_at_contact = GameHandler.time_remaining
	_camera = get_viewport().get_camera_2d() as LevelCamera
	if _camera == null:
		return false
	# The reference scrolls actual approach movement before contact collision.
	_camera.follow_position(player.climbing.approach_position.x)
	if not _camera.acquire_scroll_lock(self):
		return false
	player.on_level_end()
	active = true
	_music_started = false
	_music_ticks = 0
	_wait_frames = 0
	_generation += 1
	_previous_climb_controls = player.climb_state.controls_enabled
	player.climb_state.controls_enabled = false
	if is_instance_valid(player._active_sound_effect):
		player._active_sound_effect.stop()
	_play_audio(flag_sound)
	_show_grab_score()
	# FlagpoleRoutine also runs after collision on the contact tick.
	if not _player_reached_descent_cutoff():
		_advance_flag_and_popup(get_physics_process_delta_time())
	_set_phase(Phase.DESCEND)
	if not _valid():
		return false
	_walk_endpoint = _castle.doorway.global_position
	_dismount_ticks = 0
	_install_motion.call_deferred(_generation)
	set_physics_process(true)
	return true


func _install_motion(generation: int) -> void:
	if not _valid() or generation != _generation:
		return
	if not is_instance_valid(_pole) or _pole.is_shutdown:
		_level.cancel_ending()
		return
	if not _player.state_machine.change_state(_player.climb_state):
		_level.cancel_ending()
		return
	_player.climbing.attach(_player, _pole)
	_player.climbing.place_on_side(_player, -1.0)
	_player.run_action.apply(_player.motion_values, false)
	_player.run_action.remaining_ticks = 0
	_player.run_action.running_history = false
	_player.motion_values.remove_modifier(&"ground_neutral")
	_player.climb_state.hold_pose()
	_player.scripted_motion_step = _advance_player_motion
	_descent_stop_y = maxf(
		_player.body.global_position.y, _pole.climb_bottom.global_position.y - 2.0
	)


## Called on the player's physics tick, before this presentation advances the flag.
func _advance_player_motion(delta: float) -> void:
	if not _valid() or not is_instance_valid(_player):
		return
	var body := _player.body
	if phase == Phase.DESCEND:
		if body.global_position.y < _descent_stop_y:
			if not _player.climb_state.advance_climb(Vector2.DOWN, delta):
				_level.cancel_ending()
				return
			if body.global_position.y >= _descent_stop_y:
				body.global_position.y = _descent_stop_y
				body.velocity = Vector2.ZERO
				_player.climb_state.hold_pose()
		return
	if phase == Phase.DISMOUNT:
		body.velocity = Vector2.ZERO
		_player.climb_state.hold_pose()
		_dismount_ticks -= 1
		if _dismount_ticks > 0:
			return
		# The four-pixel outward nudge clears shaft contact.
		body.global_position.x += 4.0
		if not _player.state_machine.change_state(_player.climb_state.move_state):
			_level.cancel_ending()
			return
		body.reset_physics_interpolation()
	elif phase != Phase.WALK:
		return
	_player.advance_scripted_walk(1.0, delta)
	if body.global_position.x >= _walk_endpoint.x:
		body.global_position.x = _walk_endpoint.x
		body.velocity = Vector2.ZERO
		_on_endpoint()


func _valid() -> bool:
	return (
		active
		and is_instance_valid(_level)
		and not _level.is_shutdown
		and GameHandler.current_level == _level
	)


func _physics_process(delta: float) -> void:
	if not _valid():
		cancel()
		return
	if not is_instance_valid(_castle) or _castle.is_shutdown:
		_level.cancel_ending()
		return
	if _music_started and is_instance_valid(_audio) and _audio.playing:
		_music_ticks += 1
		if _music_ticks > _music_limit:
			_audio.stop()
			_stop_music_pulse()
	if is_instance_valid(_player) and not _player.is_shutdown:
		if not is_instance_valid(_pole) or _pole.is_shutdown:
			_level.cancel_ending()
			return
		if _player.scripted_motion_step != _advance_player_motion:
			return
		if phase == Phase.DESCEND:
			if _player_reached_descent_cutoff() or _advance_flag_and_popup(delta):
				_player.climbing.place_on_side(_player, 1.0)
				_dismount_ticks = 24
				GameHandler.add_score(grab_points)
				if not _valid():
					return
				_set_phase(Phase.DISMOUNT)
		if phase == Phase.DISMOUNT and _dismount_ticks == 0:
			_set_phase(Phase.WALK)
		if (
			phase == Phase.WALK
			and _player.body.global_position.y >= _pole.climb_bottom.global_position.y + 14.0
		):
			_begin_music_and_unlock()
		_camera.follow_target(_player.body)
		_level.clamp_player_to_camera()
	if phase == Phase.RAISE_FLAG and _castle.advance_flag_raise():
		_set_phase(Phase.FIREWORKS)
		if _valid():
			fireworks_step.begin()
		return
	if phase == Phase.WAIT:
		# Hooks have completed. Give the player a visible pause after audio too.
		if is_instance_valid(_audio) and _audio.playing:
			return
		_wait_frames += 1
		if _wait_frames >= post_delay_frames:
			_set_phase(Phase.FINISHED)
			set_physics_process(false)
			if not _level.finish_ending(self) and _valid():
				_level.cancel_ending()


static func points_for_grab_height(height: float) -> int:
	# Flooring the reference Y is equivalent to rounding height above the base up.
	var pixels := ceili(height)
	if pixels >= 127:
		return 5000
	if pixels >= 81:
		return 2000
	if pixels >= 57:
		return 800
	if pixels >= 17:
		return 400
	return 100


func _show_grab_score() -> void:
	# Register the sprite at its actual anchor and present the NES pixel steps directly.
	var anchor := _pole.climb_bottom.global_position + Vector2(12, -12)
	var popup = SCORE_POPUP.instantiate()
	popup.position = _pole.to_local(anchor)
	_pole.add_child(popup)
	_score_popup = popup
	_popup_fraction = 255
	popup.show_score(grab_points, anchor)


func _advance_flag_and_popup(delta: float) -> bool:
	var speed := _player.climbing.downward_speed
	if _pole.lower_flag(delta, speed):
		return true
	if is_instance_valid(_score_popup):
		# The upward subtraction borrows on the first fractional step.
		_popup_fraction += roundi(speed * delta * 256.0)
		_score_popup.position.y -= floori(float(_popup_fraction) / 256.0)
		_popup_fraction %= 256
	return false


func _player_reached_descent_cutoff() -> bool:
	return _player.body.global_position.y >= _pole.climb_bottom.global_position.y + 2.0


func _begin_music_and_unlock() -> void:
	if _music_started:
		return
	_music_started = true
	_camera.release_scroll_lock(self)
	_play_audio(music)
	if music != null:
		_music_limit = maxi(60, ceili(music.get_length() * 60.0) + 60)
		if music_pulse != null:
			_pulse_audio = AudioStreamPlayer.new()
			_pulse_audio.bus = SoundHandler.NES_MIX_BUS
			_pulse_audio.stream = SoundHandler.one_shot_copy(music_pulse)
			add_child(_pulse_audio)
			_set_reward_voice_occupied(SoundHandler.is_reward_voice_occupied())
			_pulse_audio.play()


func _set_reward_voice_occupied(occupied: bool) -> void:
	if is_instance_valid(_pulse_audio):
		# Keep the music timeline advancing while the reward cue owns this voice.
		_pulse_audio.volume_linear = 0.0 if occupied else 1.0


func _stop_music_pulse() -> void:
	if is_instance_valid(_pulse_audio):
		_pulse_audio.stop()
		_pulse_audio.queue_free()
		_pulse_audio = null


func _play_audio(stream: AudioStream) -> void:
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.queue_free()
		_audio = null
	if stream == null:
		return
	_audio = AudioStreamPlayer.new()
	_audio.bus = SoundHandler.NES_MIX_BUS
	_audio.stream = SoundHandler.one_shot_copy(stream)
	add_child(_audio)
	_audio.play()


func _on_endpoint() -> void:
	if not _valid() or phase not in [Phase.WALK, Phase.DISMOUNT]:
		return
	_begin_music_and_unlock()
	var retired := _player
	_player = null
	retired.scripted_motion_step = Callable()
	retired.climb_state.controls_enabled = _previous_climb_controls
	retired.shutdown()
	if _level.player == retired:
		_level.player = null
	if GameHandler.current_player == retired:
		GameHandler.current_player = null
	retired.queue_free()
	if fireworks_step is CastleFireworksStep:
		fireworks_step.castle = _castle
		fireworks_step.count = CastleFireworksStep.count_for_time(
			GameHandler.time_remaining, _level.timer_enabled
		)
	_set_phase(Phase.SCORE)
	score_step.begin()


func _on_score_finished(ticket: int) -> void:
	if not _valid() or phase != Phase.SCORE or ticket != score_step.current_ticket:
		return
	if not is_instance_valid(_castle) or _castle.is_shutdown:
		_level.cancel_ending()
		return
	_castle.raise_flag()
	_set_phase(Phase.RAISE_FLAG)


func _on_fireworks_finished(ticket: int) -> void:
	if not _valid() or phase != Phase.FIREWORKS or ticket != fireworks_step.current_ticket:
		return
	_wait_frames = 0
	_set_phase(Phase.WAIT)


func _set_phase(value: Phase) -> void:
	phase = value
	phase_changed.emit(value)


func cancel() -> void:
	_generation += 1
	active = false
	set_physics_process(false)
	_stop_music_pulse()
	if is_instance_valid(_score_popup):
		_score_popup.hide()
		_score_popup.queue_free()
	_score_popup = null
	score_step.cancel()
	fireworks_step.cancel()
	if is_instance_valid(_camera):
		_camera.release_scroll_lock(self)
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.queue_free()
		_audio = null
	if is_instance_valid(_player):
		_player.climb_state.controls_enabled = _previous_climb_controls
		if _player.scripted_motion_step == _advance_player_motion:
			_player.scripted_motion_step = Callable()
			if not _player.is_shutdown:
				_player.state_machine.change_state(_player.state_machine.initial_state)
	_player = null
	if is_instance_valid(_pole) and not _pole.is_shutdown:
		_pole.reset_flag()
	if is_instance_valid(_castle) and not _castle.is_shutdown:
		_castle.reset_flag()


func _exit_tree() -> void:
	cancel()


func is_finished() -> bool:
	return _valid() and phase == Phase.FINISHED
