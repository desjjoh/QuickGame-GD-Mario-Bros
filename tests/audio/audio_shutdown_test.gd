extends Node

const FINISH_TEST := preload("res://tests/fixtures/finish_test.gd")


func create_stopped_voices() -> Array[WeakRef]:
	var references: Array[WeakRef] = []
	for index in range(16):
		var stream := AudioStreamWAV.new()
		stream.data = PackedByteArray([0, 0, 1, 0, 0, 0, 1, 0])
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voice.stream = stream
		voice.play()
		references.append(weakref(stream))
		references.append(weakref(voice.get_stream_playback()))
		voice.stop()
		voice.free()
	return references


func _ready() -> void:
	var references := create_stopped_voices()
	assert(await FINISH_TEST.drain_audio(get_tree()))
	for reference in references:
		assert(reference.get_ref() == null, "Stopped audio resource survived mix-thread cleanup.")
	print("audio_shutdown_test: PASS")
	await FINISH_TEST.finish(get_tree())
