extends Node

enum Track { OVERWORLD, UNDERGROUND, NONE }

const STARMAN_TRACK := Track.NONE + 1
const STREAMS = {
	Track.OVERWORLD: preload("res://assets/audio/music/overworld.wav"),
	Track.UNDERGROUND: preload("res://assets/audio/music/underground.wav"),
	STARMAN_TRACK: preload("res://assets/audio/music/starman.wav"),
}

var _voice := AudioStreamPlayer.new()
var _owner_id := 0
var _area_track := Track.NONE
var _loops: Dictionary[int, AudioStreamWAV] = {}


func _ready() -> void:
	_voice.name = "BackgroundMusic"
	_voice.bus = SoundHandler.NES_MIX_BUS
	add_child(_voice)
	for track: int in STREAMS:
		var stream := STREAMS[track].duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		_loops[track] = stream


func play_area(level: Node, track: Track, starman: bool = false) -> void:
	var same_owner := _owner_id == level.get_instance_id()
	_owner_id = level.get_instance_id()
	_area_track = track
	if same_owner and starman and _voice.stream == _loops[STARMAN_TRACK] and _voice.playing:
		return
	_play(STARMAN_TRACK if starman else track)


func play_starman(level: Node) -> void:
	if is_instance_valid(level) and _owner_id == level.get_instance_id():
		_play(STARMAN_TRACK)


func end_starman(level: Node) -> void:
	if (
		is_instance_valid(level)
		and _owner_id == level.get_instance_id()
		and _voice.stream == _loops[STARMAN_TRACK]
	):
		_play(_area_track)


func _play(track: int) -> void:
	_voice.stop()
	_voice.stream = _loops.get(track)
	if _voice.stream != null:
		_voice.play()


func stop_area(level: Node) -> void:
	if _owner_id != level.get_instance_id():
		return
	_owner_id = 0
	_voice.stop()
	_voice.stream = null
