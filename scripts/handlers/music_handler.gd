extends Node

enum Track { OVERWORLD, UNDERGROUND, NONE }
enum Pace { NORMAL, FAST, WARNING }

const STARMAN_TRACK := Track.NONE + 1
const STREAMS = {
	Track.OVERWORLD: preload("res://assets/audio/music/overworld.wav"),
	Track.UNDERGROUND: preload("res://assets/audio/music/underground.wav"),
	STARMAN_TRACK: preload("res://assets/audio/music/starman.wav"),
}
const FAST_STREAMS = {
	Track.OVERWORLD: preload("res://assets/audio/music/overworld_fast.wav"),
	Track.UNDERGROUND: preload("res://assets/audio/music/underground_fast.wav"),
	STARMAN_TRACK: preload("res://assets/audio/music/starman_fast.wav"),
}
const FAST_OVERWORLD_SECTIONS := preload("res://assets/audio/music/overworld_fast_sections.tres")
const WARNING_STEMS := [
	preload("res://assets/audio/music/hurry_up_pulse_one.wav"),
	preload("res://assets/audio/music/hurry_up_pulse_two.wav"),
	preload("res://assets/audio/music/hurry_up_triangle.wav"),
]

var _voice := AudioStreamPlayer.new()
var _warning := AudioStreamSynchronized.new()
var _owner_id := 0
var _area_track := Track.NONE
var _requested_track: int = Track.NONE
var _fast := false
var _warning_resume_position := 0.0
var _loops: Dictionary[int, AudioStreamWAV] = {}
var _fast_loops: Dictionary[int, AudioStreamWAV] = {}


func _ready() -> void:
	_voice.name = "BackgroundMusic"
	_voice.bus = SoundHandler.NES_MIX_BUS
	add_child(_voice)
	_voice.finished.connect(_finish_warning)
	_loops = _make_loops(STREAMS)
	_fast_loops = _make_loops(FAST_STREAMS)
	_warning.stream_count = WARNING_STEMS.size()
	for index in range(WARNING_STEMS.size()):
		_warning.set_sync_stream(index, SoundHandler.one_shot_copy(WARNING_STEMS[index]))
	set_process(false)


func _make_loops(streams: Dictionary) -> Dictionary[int, AudioStreamWAV]:
	var loops: Dictionary[int, AudioStreamWAV] = {}
	for track: int in streams:
		var stream := streams[track].duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		loops[track] = stream
	return loops


func play_area(level: Node, track: Track, starman: bool = false, pace: Pace = Pace.NORMAL) -> void:
	var same_owner := _owner_id == level.get_instance_id()
	_owner_id = level.get_instance_id()
	_area_track = track
	_requested_track = STARMAN_TRACK if starman else track
	_fast = pace != Pace.NORMAL
	if pace == Pace.WARNING:
		_play_warning(0.0)
		return
	if same_owner and starman and _voice.stream == _requested_loop() and _voice.playing:
		return
	_play_stream(_requested_loop())


func start_hurry(level: Node) -> void:
	if _owner_id != level.get_instance_id() or _fast:
		return
	var resume_position := 0.0
	if _requested_track == Track.OVERWORLD:
		resume_position = _next_fast_overworld_section()
	_fast = true
	_play_warning(resume_position)


func play_starman(level: Node) -> void:
	if is_instance_valid(level) and _owner_id == level.get_instance_id():
		_requested_track = STARMAN_TRACK
		_warning_resume_position = 0.0
		if _voice.stream != _warning:
			_play_stream(_requested_loop())


func end_starman(level: Node) -> void:
	if (
		is_instance_valid(level)
		and _owner_id == level.get_instance_id()
		and _requested_track == STARMAN_TRACK
	):
		_requested_track = _area_track
		_warning_resume_position = 0.0
		if _voice.stream != _warning:
			_play_stream(_requested_loop())


func _requested_loop() -> AudioStreamWAV:
	return (_fast_loops if _fast else _loops).get(_requested_track)


func _next_fast_overworld_section() -> float:
	# The fast arrangement uses two thirds of the normal note durations.
	var fast_frame := _voice.get_playback_position() * 40.0
	var starts: PackedInt32Array = FAST_OVERWORLD_SECTIONS.get_meta("start_frames")
	for start in starts:
		if start > fast_frame:
			return float(start) / 60.0
	return 0.0


func _play_warning(resume_position: float) -> void:
	_warning_resume_position = resume_position
	_update_warning_channels()
	_play_stream(_warning)


func _finish_warning() -> void:
	if _owner_id != 0 and _voice.stream == _warning:
		_play_stream(_requested_loop(), _warning_resume_position)


func _process(_delta: float) -> void:
	_update_warning_channels()


func _update_warning_channels() -> void:
	# The action and reward voices take over their respective music pulse.
	_warning.set_sync_stream_volume(0, -INF if SoundHandler.is_action_voice_occupied() else 0.0)
	_warning.set_sync_stream_volume(1, -INF if SoundHandler.is_reward_voice_occupied() else 0.0)


func _play_stream(stream: AudioStream, from_position: float = 0.0) -> void:
	_voice.stop()
	_voice.stream = stream
	set_process(stream == _warning)
	if stream != null:
		_voice.play(from_position)


func stop_area(level: Node) -> void:
	if _owner_id != level.get_instance_id():
		return
	_owner_id = 0
	_play_stream(null)
