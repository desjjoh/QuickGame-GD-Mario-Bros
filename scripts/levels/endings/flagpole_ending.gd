class_name FlagpoleEndingPresentation
extends LevelEndingPresentation

const AudioMix = preload("res://scripts/audio/sound_effect_mix.gd")
const SOUND_MIX = preload("res://assets/audio/sound_effect_mix.tres")
enum Phase { IDLE, DESCEND, DISMOUNT, WALK, SCORE, FIREWORKS, WAIT, FINISHED }
signal phase_changed(phase: Phase)

@export var area_id: StringName = &"main"
@export var flagpole_cell: Vector2i
@export var endpoint: Marker2D
@export var flag_sound: AudioStream
@export var music: AudioStream
@export var post_delay_frames: int = 126
@onready var score_step: EndingStep = $Score
@onready var fireworks_step: EndingStep = $Fireworks

var phase: Phase = Phase.IDLE
var active: bool = false
var grab_height: float = 0.0
var remaining_time_at_contact: int = 0
var _level: BaseLevel
var _player: BasePlayer
var _pole: FlagpoleEntity
var _camera: LevelCamera
var _state: PlayerFlagpoleEndingState
var _audio: AudioStreamPlayer
var _wait_frames: int = 0
var _generation: int = 0
var _previous_climb_controls: bool = true
var _music_started: bool = false
var _music_ticks: int = 0
var _music_limit: int = 0


func _ready() -> void:
	process_physics_priority = 50
	set_physics_process(false)
	score_step.finished.connect(_on_score_finished)
	fireworks_step.finished.connect(_on_fireworks_finished)


func bind_entity(entity: BaseEntity, cell: Vector2i, area: BaseLevelArea) -> void:
	if entity is FlagpoleEntity and cell == flagpole_cell and area.area_id == area_id:
		entity.player_attached.connect(_on_attached.bind(entity))


func _on_attached(player: BasePlayer, pole: FlagpoleEntity) -> void:
	if active or player.state_machine.current_state == player.flagpole_ending_state:
		return
	var level := get_parent() as BaseLevel
	if level != null:
		level.begin_ending(self, player, pole)


func start(level: BaseLevel, player: BasePlayer, source: BaseEntity) -> bool:
	if (
		active
		or not source is FlagpoleEntity
		or endpoint == null
		or player.flagpole_ending_state == null
	):
		return false
	_level = level
	_player = player
	_pole = source as FlagpoleEntity
	_pole.reset_flag()
	grab_height = maxf(0.0, _pole.climb_bottom.global_position.y - player.body.global_position.y)
	remaining_time_at_contact = GameHandler.time_remaining
	_camera = get_viewport().get_camera_2d() as LevelCamera
	if _camera == null:
		return false
	# The reference scrolls actual approach movement before contact collision.
	_camera.follow_position(player.climbing.approach_position.x)
	if not _camera.acquire_scroll_lock(self):
		return false
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
	# FlagpoleRoutine also runs after collision on the contact tick.
	_pole.lower_flag(get_physics_process_delta_time(), player.climbing.downward_speed)
	_set_phase(Phase.DESCEND)
	if not _valid():
		return false
	_state = player.flagpole_ending_state
	_state.configure(_pole, endpoint.global_position)
	if not _state.endpoint_reached.is_connected(_on_endpoint):
		_state.endpoint_reached.connect(_on_endpoint)
	_install_state.call_deferred(_generation)
	set_physics_process(true)
	return true


func _install_state(generation: int) -> void:
	if not _valid() or generation != _generation:
		return
	if not is_instance_valid(_pole) or _pole.is_shutdown:
		_level.cancel_ending()
		return
	if not _player.state_machine.change_state(_state):
		_level.cancel_ending()


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
	if _music_started and is_instance_valid(_audio) and _audio.playing:
		_music_ticks += 1
		if _music_ticks > _music_limit:
			_audio.stop()
	if is_instance_valid(_player) and not _player.is_shutdown:
		if not is_instance_valid(_pole) or _pole.is_shutdown:
			_level.cancel_ending()
			return
		if _player.state_machine.current_state != _state:
			return
		if phase == Phase.DESCEND:
			var flag_done := _pole.lower_flag(delta, _player.climbing.downward_speed)
			if (
				flag_done
				or _player.body.global_position.y >= _pole.climb_bottom.global_position.y + 2.0
			):
				_state.begin_dismount()
				_set_phase(Phase.DISMOUNT)
		if phase == Phase.DISMOUNT and _state.phase == PlayerFlagpoleEndingState.Phase.WALK:
			_set_phase(Phase.WALK)
		if (
			phase == Phase.WALK
			and _player.body.global_position.y >= _pole.climb_bottom.global_position.y + 14.0
		):
			_begin_music_and_unlock()
		_camera.follow_target(_player.body)
		_level.clamp_player_to_camera()
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


func _begin_music_and_unlock() -> void:
	if _music_started:
		return
	_music_started = true
	_camera.release_scroll_lock(self)
	_play_audio(music)
	if music != null:
		_music_limit = maxi(60, ceili(music.get_length() * 60.0) + 60)


func _play_audio(stream: AudioStream) -> void:
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.queue_free()
		_audio = null
	if stream == null:
		return
	_audio = AudioStreamPlayer.new()
	_audio.stream = AudioMix.one_shot_copy(stream)
	_audio.volume_db = SOUND_MIX.volume_for(stream)
	add_child(_audio)
	_audio.play()


func _on_endpoint() -> void:
	if not _valid() or phase not in [Phase.WALK, Phase.DISMOUNT]:
		return
	_begin_music_and_unlock()
	var retired := _player
	_player = null
	retired.climb_state.controls_enabled = _previous_climb_controls
	retired.shutdown()
	if _level.player == retired:
		_level.player = null
	if GameHandler.current_player == retired:
		GameHandler.current_player = null
	retired.queue_free()
	_set_phase(Phase.SCORE)
	score_step.begin()


func _on_score_finished(ticket: int) -> void:
	if not _valid() or phase != Phase.SCORE or ticket != score_step.current_ticket:
		return
	_set_phase(Phase.FIREWORKS)
	fireworks_step.begin()


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
		if not _player.is_shutdown and _player.state_machine.current_state == _state:
			_player.state_machine.change_state(_player.state_machine.initial_state)
	_player = null
	if is_instance_valid(_pole) and not _pole.is_shutdown:
		_pole.reset_flag()


func _exit_tree() -> void:
	cancel()


func is_finished() -> bool:
	return _valid() and phase == Phase.FINISHED
