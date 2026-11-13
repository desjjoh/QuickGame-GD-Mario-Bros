extends Node

signal reward_voice_changed(occupied: bool)

const NES_MIX_BUS: StringName = &"NES_Mix"
const ACTION_VOICES := &"nes_square_one_voices"
const ACTION_CUES := [
	&"jump_small",
	&"jump_big",
	&"bump",
	&"fireball",
	&"enemy_smack",
	&"stomp",
	&"flagpole",
	&"pipe",
	&"injury"
]
const WAVEFORMS := preload("res://scripts/audio/nes_waveform_renderer.gd")
const PEAK_SAMPLE := 5900
# Corrections measured through NES_Mix against isolated Mesen cues.
const PULSE_CUE_CORRECTIONS_DB := {
	&"bowser_fall": -11.44,
	&"bump": -11.89,
	&"coin": -11.64,
	&"enemy_smack": -10.88,
	&"extra_life": -11.70,
	&"fireball": -12.34,
	&"fireworks": -11.58,
	&"flagpole": -11.46,
	&"jump_big": -12.12,
	&"jump_small": -10.29,
	&"pause": -11.76,
	&"pipe": -11.90,
	&"power_up_grab": -11.88,
	&"power_up_reveal": -12.98,
	&"stomp": -12.59,
	&"timer_tick": -11.78,
}

var _sounds: Dictionary[StringName, AudioStream] = {}
var _square_two := AudioStreamPlayer.new()
var _pause_voice := AudioStreamPlayer.new()


func _ready() -> void:
	_pause_voice.name = "PauseCue"
	_pause_voice.bus = NES_MIX_BUS
	_pause_voice.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_voice)
	_sounds[&"pause"] = _build_pause_cue()
	_square_two.name = "Square2Sfx"
	_square_two.bus = NES_MIX_BUS
	add_child(_square_two)
	_square_two.finished.connect(func(): reward_voice_changed.emit(false))
	_register_square_two_cues()
	_register_action_cues()
	_calibrate_pulse_cues()


func _calibrate_pulse_cues() -> void:
	for cue: StringName in PULSE_CUE_CORRECTIONS_DB:
		var stream := _sounds[cue] as AudioStreamWAV
		var pcm := stream.data
		var scale := db_to_linear(PULSE_CUE_CORRECTIONS_DB[cue])
		for offset in range(0, pcm.size(), 2):
			pcm.encode_s16(offset, roundi(pcm.decode_s16(offset) * scale))
		# Injury shares the pipe stream, so this also calibrates that cue once.
		stream.data = pcm


static func _build_pause_cue() -> AudioStreamWAV:
	# NES SoundEngine: offsets $44/$64, 6/6/6/24 frames, control $84.
	# Each register reload restarts the volume envelope.
	var pause_pcm := PackedByteArray()
	for note: Array in [[0x54, 6], [0x6a, 6], [0x54, 6], [0x6a, 24]]:
		pause_pcm.append_array(WAVEFORMS.pulse(PEAK_SAMPLE, [note[0]], [note[1]], 0.5, 5).data)
	return WAVEFORMS.pcm_stream(pause_pcm)


func _register_square_two_cues() -> void:
	_sounds[&"coin"] = WAVEFORMS.pulse(PEAK_SAMPLE, [113, 84], [5, 48], 0.5, 14, true)
	_sounds[&"extra_life"] = WAVEFORMS.pulse(
		PEAK_SAMPLE, [84, 71, 42, 53, 47, 35], [8, 8, 8, 8, 8, 8], 0.5, 3
	)
	# ContinuePowerUpGrab traverses its 27-entry frequency table backward,
	# two frames per entry, Square 2 control $5d and sweep $7f.
	var grab_pcm := PackedByteArray()
	var grab: AudioStreamWAV
	for period: int in [
		0xd5,
		0x11d,
		0xd5,
		0xa9,
		0x8e,
		0x6a,
		0x8e,
		0x10d,
		0xd5,
		0xb3,
		0x86,
		0xb3,
		0x86,
		0x6a,
		0x59,
		0x43,
		0x59,
		0xef,
		0xbe,
		0xa0,
		0x77,
		0xa0,
		0x77,
		0x5f,
		0x50,
		0x3b,
		0x50
	]:
		grab = WAVEFORMS.swept_pulse(PEAK_SAMPLE, period, [2], [0x5d], [0x7f], [], {}, false)
		grab_pcm.append_array(grab.data)
	grab.data = grab_pcm
	_sounds[&"power_up_grab"] = grab
	# The reveal table holds the previous period when a frequency entry is zero.
	_sounds[&"power_up_reveal"] = WAVEFORMS.pulse(
		PEAK_SAMPLE,
		[0x1ab, 0x11d, 0x10d, 0x193, 0x10d, 0xfe, 0x17c, 0xfe, 0xef, 0x167, 0xef, 0xe2],
		[3, 2, 2, 4, 2, 2, 4, 2, 2, 4, 2, 2],
		0.5
	)
	# Square 2 control $98 selects a 50% duty cycle and constant volume 8.
	_sounds[&"timer_tick"] = WAVEFORMS.swept_pulse(
		PEAK_SAMPLE, 0x71, [6], [0x98], [0x7f], [], {}, false
	)
	# Square 2 blast: $5e/$18 frequency offsets, $94/$93 sweep, $9f control.
	var blast := WAVEFORMS.swept_pulse(PEAK_SAMPLE, 0x2f9, [8], [0x9f], [0x94], [], {}, false)
	var blast_pcm := blast.data
	blast_pcm.append_array(
		WAVEFORMS.swept_pulse(PEAK_SAMPLE, 0x17c, [24], [0x9f], [0x93], [], {}, false).data
	)
	blast.data = blast_pcm
	_sounds[&"fireworks"] = blast
	# The final bridge entry switches to the 56-tick Bowser fall cue.
	var bowser_fall := WAVEFORMS.swept_pulse(
		PEAK_SAMPLE, 0x17c, [48], [0x9f], [0xc4], [], {}, false
	)
	var fall_pcm := bowser_fall.data
	fall_pcm.append_array(
		WAVEFORMS.swept_pulse(PEAK_SAMPLE, 0x475, [8], [0x9f], [0xa4], [], {}, false).data
	)
	bowser_fall.data = fall_pcm
	_sounds[&"bowser_fall"] = bowser_fall


func _register_action_cues() -> void:
	_sounds[&"jump_small"] = WAVEFORMS.swept_pulse(
		PEAK_SAMPLE, 0x0fe, [3, 5, 32], [0x82, 0x5f, 0x48], [0xa7, 0xf6, 0xbc]
	)
	# PlayBigJump uses frequency-table offset $18 ($17c), with the shared jump envelope.
	_sounds[&"jump_big"] = WAVEFORMS.swept_pulse(
		PEAK_SAMPLE, 0x17c, [3, 5, 32], [0x82, 0x5f, 0x48], [0xa7, 0xf6, 0xbc]
	)
	_sounds[&"bump"] = WAVEFORMS.swept_pulse(PEAK_SAMPLE, 0x23a, [4, 6], [0x9e, 0x9e], [0x93, 0xbb])
	_sounds[&"fireball"] = WAVEFORMS.swept_pulse(PEAK_SAMPLE, 0x23a, [5], [0x9e], [0x99])
	_sounds[&"brick_shatter"] = (
		load("res://assets/audio/effects/brick_shatter.wav") as AudioStreamWAV
	)
	_sounds[&"bowser_flame"] = _build_bowser_flame()
	_sounds[&"enemy_smack"] = WAVEFORMS.swept_pulse(
		PEAK_SAMPLE,
		0xef,
		[14],
		[0x9f],
		[0xcb],
		[0x9f, 0x90, 0x90, 0x90, 0x90, 0x90, 0x9f, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90],
		{6: 0xa0}
	)
	# The NES counts this envelope down and writes the timer low byte on frame 8.
	_sounds[&"stomp"] = WAVEFORMS.swept_pulse(
		PEAK_SAMPLE,
		0xfe,
		[14],
		[0x9e],
		[0x9c],
		[0x92, 0x93, 0x95, 0x97, 0x9a, 0x90, 0x90, 0x92, 0x94, 0x95, 0x96, 0x98, 0x9b, 0x9f],
		{8: 0x9e}
	)

	_sounds[&"flagpole"] = WAVEFORMS.swept_pulse(PEAK_SAMPLE, 0x1fc, [64], [0x99], [0xbc])
	var pipe_data := PackedByteArray()
	# The first trigger occurs three frames into the 47-frame sound.
	pipe_data.resize(3 * WAVEFORMS.SAMPLES_PER_FRAME * 2)
	var pipe: AudioStreamWAV
	for frames: int in [4, 12, 4, 12, 4, 8]:
		pipe = WAVEFORMS.swept_pulse(PEAK_SAMPLE, 0x54, [frames], [0x9a], [0x91])
		pipe_data.append_array(pipe.data)
	pipe.data = pipe_data
	_sounds[&"pipe"] = pipe
	# NES Sfx_PipeDown_Injury uses the same Square 1 routine for both events.
	_sounds[&"injury"] = pipe


static func _build_bowser_flame() -> AudioStreamWAV:
	# NES noise period $0f uses the long LFSR and a 4068-cycle timer.
	# The game reads the volume table backward, once every two ticks.
	var envelope: Array[int] = [
		5,
		6,
		6,
		7,
		7,
		8,
		9,
		9,
		10,
		10,
		12,
		13,
		13,
		14,
		14,
		15,
		15,
		15,
		15,
		14,
		13,
		12,
		14,
		15,
		15,
		14,
		13,
		12,
		10,
		8,
		6,
		4
	]
	# Read the NES envelope backward. The first control lasts one tick, with a final mute tick.
	envelope.reverse()
	var frame_lengths: Array[int] = []
	frame_lengths.resize(envelope.size())
	frame_lengths.fill(2)
	frame_lengths[0] = 1
	var noise_peak := PEAK_SAMPLE * (0.00494 / 0.00752) / 2.0
	return WAVEFORMS.noise(4068, noise_peak, envelope, frame_lengths, envelope.size() * 2)


func get_sound(cue: StringName) -> AudioStream:
	return _sounds.get(cue)


func register_action_voice(voice: AudioStreamPlayer) -> void:
	for cue: StringName in ACTION_CUES:
		if voice.stream == _sounds[cue]:
			voice.add_to_group(ACTION_VOICES)
			return


func is_action_voice_occupied() -> bool:
	for voice: AudioStreamPlayer in get_tree().get_nodes_in_group(ACTION_VOICES):
		if voice.playing:
			return true
	return false


func play_pause() -> void:
	_pause_voice.stream = get_sound(&"pause")
	_pause_voice.play()


func stop_pause() -> void:
	_pause_voice.stop()


func play_reward(cue: StringName) -> void:
	var sound := get_sound(cue)
	if sound == null:
		return
	# The reference protects 1 UP from later requests on this voice.
	if _square_two.playing and _square_two.stream == get_sound(&"extra_life"):
		return
	_square_two.stream = sound
	_square_two.play()
	reward_voice_changed.emit(true)


func is_reward_voice_occupied() -> bool:
	return _square_two.playing


func stop_reward(cue: StringName = &"") -> void:
	if cue != &"" and _square_two.stream != get_sound(cue):
		return
	_square_two.stop()
	reward_voice_changed.emit(false)


func one_shot_copy(sound: AudioStream) -> AudioStream:
	if sound == null:
		return null
	var copy := sound.duplicate() as AudioStream
	if copy is AudioStreamWAV:
		copy.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif copy is AudioStreamMP3 or copy is AudioStreamOggVorbis:
		copy.loop = false
	return copy
