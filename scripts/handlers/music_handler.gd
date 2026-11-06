extends Node

enum Track { OVERWORLD, UNDERGROUND, NONE }

const STREAMS = {
	Track.OVERWORLD: preload("res://assets/audio/music/overworld.wav"),
	Track.UNDERGROUND: preload("res://assets/audio/music/underground.wav"),
}

var _voice := AudioStreamPlayer.new()
var _owner_id := 0
var _loops: Dictionary[int, AudioStreamWAV] = {}


func _ready() -> void:
	_voice.name = "BackgroundMusic"
	add_child(_voice)
	for track: int in STREAMS:
		var stream := STREAMS[track].duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		_loops[track] = stream


func play_area(level: Node, track: Track) -> void:
	_owner_id = level.get_instance_id()
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
