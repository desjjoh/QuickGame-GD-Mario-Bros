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
const SAMPLE_RATE := 44100
const SAMPLES_PER_FRAME := 735
const CPU_HZ := 1789773.0
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
		pause_pcm.append_array(_build_pulse([note[0]], [note[1]], 0.5, 5).data)
	return _pcm_stream(pause_pcm)


func _register_square_two_cues() -> void:
	_sounds[&"coin"] = _build_pulse([113, 84], [5, 48], 0.5, 14, true)
	_sounds[&"extra_life"] = _build_pulse([84, 71, 42, 53, 47, 35], [8, 8, 8, 8, 8, 8], 0.5, 3)
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
		grab = _build_swept_pulse(period, [2], [0x5d], [0x7f], [], {}, false)
		grab_pcm.append_array(grab.data)
	grab.data = grab_pcm
	_sounds[&"power_up_grab"] = grab
	# The reveal table holds the previous period when a frequency entry is zero.
	_sounds[&"power_up_reveal"] = _build_pulse(
		[0x1ab, 0x11d, 0x10d, 0x193, 0x10d, 0xfe, 0x17c, 0xfe, 0xef, 0x167, 0xef, 0xe2],
		[3, 2, 2, 4, 2, 2, 4, 2, 2, 4, 2, 2],
		0.5
	)
	# Square 2 control $98 selects a 50% duty cycle and constant volume 8.
	_sounds[&"timer_tick"] = _build_swept_pulse(0x71, [6], [0x98], [0x7f], [], {}, false)
	# Square 2 blast: $5e/$18 frequency offsets, $94/$93 sweep, $9f control.
	var blast := _build_swept_pulse(0x2f9, [8], [0x9f], [0x94], [], {}, false)
	var blast_pcm := blast.data
	blast_pcm.append_array(_build_swept_pulse(0x17c, [24], [0x9f], [0x93], [], {}, false).data)
	blast.data = blast_pcm
	_sounds[&"fireworks"] = blast
	# The final bridge entry switches to the 56-tick Bowser fall cue.
	var bowser_fall := _build_swept_pulse(0x17c, [48], [0x9f], [0xc4], [], {}, false)
	var fall_pcm := bowser_fall.data
	fall_pcm.append_array(_build_swept_pulse(0x475, [8], [0x9f], [0xa4], [], {}, false).data)
	bowser_fall.data = fall_pcm
	_sounds[&"bowser_fall"] = bowser_fall


func _register_action_cues() -> void:
	_sounds[&"jump_small"] = _build_swept_pulse(
		0x0fe, [3, 5, 32], [0x82, 0x5f, 0x48], [0xa7, 0xf6, 0xbc]
	)
	# PlayBigJump uses frequency-table offset $18 ($17c), with the shared jump envelope.
	_sounds[&"jump_big"] = _build_swept_pulse(
		0x17c, [3, 5, 32], [0x82, 0x5f, 0x48], [0xa7, 0xf6, 0xbc]
	)
	_sounds[&"bump"] = _build_swept_pulse(0x23a, [4, 6], [0x9e, 0x9e], [0x93, 0xbb])
	_sounds[&"fireball"] = _build_swept_pulse(0x23a, [5], [0x9e], [0x99])
	_sounds[&"brick_shatter"] = (
		load("res://assets/audio/effects/brick_shatter.wav") as AudioStreamWAV
	)
	_sounds[&"bowser_flame"] = _build_bowser_flame()
	_sounds[&"enemy_smack"] = _build_swept_pulse(
		0xef,
		[14],
		[0x9f],
		[0xcb],
		[0x9f, 0x90, 0x90, 0x90, 0x90, 0x90, 0x9f, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90],
		{6: 0xa0}
	)
	# The NES counts this envelope down and writes the timer low byte on frame 8.
	_sounds[&"stomp"] = _build_swept_pulse(
		0xfe,
		[14],
		[0x9e],
		[0x9c],
		[0x92, 0x93, 0x95, 0x97, 0x9a, 0x90, 0x90, 0x92, 0x94, 0x95, 0x96, 0x98, 0x9b, 0x9f],
		{8: 0x9e}
	)

	_sounds[&"flagpole"] = _build_swept_pulse(0x1fc, [64], [0x99], [0xbc])
	var pipe_data := PackedByteArray()
	# The first trigger occurs three frames into the 47-frame sound.
	pipe_data.resize(3 * SAMPLES_PER_FRAME * 2)
	var pipe: AudioStreamWAV
	for frames: int in [4, 12, 4, 12, 4, 8]:
		pipe = _build_swept_pulse(0x54, [frames], [0x9a], [0x91])
		pipe_data.append_array(pipe.data)
	pipe.data = pipe_data
	_sounds[&"pipe"] = pipe
	# NES Sfx_PipeDown_Injury uses the same Square 1 routine for both events.
	_sounds[&"injury"] = pipe


static func _build_bowser_flame() -> AudioStreamWAV:
	# NES noise period $0f uses the long LFSR and a 4068-cycle timer.
	# The game reads the volume table backward, once every two ticks.
	var envelope := [
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
	var pcm := PackedByteArray()
	pcm.resize(envelope.size() * 2 * SAMPLES_PER_FRAME * 2)
	var register := 1
	var noise_phase := 0.0
	var phase_step := CPU_HZ / (4068.0 * SAMPLE_RATE)
	var noise_peak := PEAK_SAMPLE * (0.00494 / 0.00752) / 2.0
	var sample := 0
	# The first control lasts one tick. The final write is muted on that same tick.
	for index in range(envelope.size() - 1, -1, -1):
		var amplitude := roundi(noise_peak * int(envelope[index]) / 15.0)
		var ticks := 1 if index == envelope.size() - 1 else 2
		for _sample_in_step in range(ticks * SAMPLES_PER_FRAME):
			noise_phase += phase_step
			if noise_phase >= 1.0:
				noise_phase -= 1.0
				var feedback := (register ^ (register >> 1)) & 1
				register = (register >> 1) | (feedback << 14)
			pcm.encode_s16(sample * 2, amplitude if (register & 1) == 0 else -amplitude)
			sample += 1
	return _pcm_stream(pcm)


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


static func _build_pulse(
	periods: Array[int],
	note_frames: Array[int],
	duty: float,
	envelope_ticks: int = 0,
	sustain_envelope: bool = false
) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	var phase := 0.0
	for note in range(periods.size()):
		var phase_step := CPU_HZ / (16.0 * (periods[note] + 1) * SAMPLE_RATE)
		var sample_count := note_frames[note] * SAMPLES_PER_FRAME
		var offset := pcm.size()
		pcm.resize(offset + sample_count * 2)
		for sample in range(sample_count):
			var gain := 1.0
			if envelope_ticks > 0:
				# The coin's second tone updates pitch without restarting its envelope.
				var elapsed := sample + ((offset >> 1) if sustain_envelope else 0)
				var envelope_step := floori(elapsed * 4.0 / (SAMPLES_PER_FRAME * envelope_ticks))
				gain = maxf(0.0, 1.0 - envelope_step / 15.0)
			var amplitude := roundi(PEAK_SAMPLE * gain)
			pcm.encode_s16(offset + sample * 2, amplitude if phase < duty else -amplitude)
			phase = fposmod(phase + phase_step, 1.0)
	return _pcm_stream(pcm)


# Render pulse control and sweep changes on a nominal 60 Hz clock.
static func _build_swept_pulse(
	period: int,
	frames: Array[int],
	controls: Array[int],
	sweeps: Array[int],
	frame_controls: Array[int] = [],
	period_low_byte_writes: Dictionary[int, int] = {},
	square_one: bool = true
) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	var phase := 0.0
	for section in range(frames.size()):
		var control := controls[section]
		var sweep := sweeps[section]
		var duty := 0.5 if (control & 0xc0) == 0x80 else 0.25
		var sweep_interval := ((sweep >> 4) & 7) + 1
		var shift := sweep & 7
		var sample_count := frames[section] * SAMPLES_PER_FRAME
		var offset := pcm.size()
		pcm.resize(offset + sample_count * 2)
		var previous_clock := 0
		for sample in range(sample_count):
			if sample % SAMPLES_PER_FRAME == 0:
				var frame := floori(float((offset >> 1) + sample) / SAMPLES_PER_FRAME)
				if frame < frame_controls.size():
					control = frame_controls[frame]
					duty = 0.5 if (control & 0xc0) == 0x80 else 0.25
				if period_low_byte_writes.has(frame):
					period = (period & ~0xff) | period_low_byte_writes[frame]
			var clock := floori(sample * 2.0 / SAMPLES_PER_FRAME)
			if clock != previous_clock and clock % sweep_interval == 0:
				var change := period >> shift
				# Square 1 uses one's complement for a negated sweep.
				period = period - change - int(square_one) if (sweep & 8) != 0 else period + change
			previous_clock = clock
			var volume := control & 15
			if (control & 16) == 0:
				var elapsed := sample + (offset >> 1)
				var decay := floori(elapsed * 4.0 / (SAMPLES_PER_FRAME * (volume + 1)))
				volume = maxi(0, 15 - decay)
			var amplitude := roundi(PEAK_SAMPLE * volume / 15.0) if period >= 8 else 0
			pcm.encode_s16(offset + sample * 2, amplitude if phase < duty else -amplitude)
			phase = fposmod(phase + CPU_HZ / (16.0 * (period + 1) * SAMPLE_RATE), 1.0)
	return _pcm_stream(pcm)


static func _pcm_stream(pcm: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = pcm
	return stream


func one_shot_copy(sound: AudioStream) -> AudioStream:
	if sound == null:
		return null
	var copy := sound.duplicate() as AudioStream
	if copy is AudioStreamWAV:
		copy.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif copy is AudioStreamMP3 or copy is AudioStreamOggVorbis:
		copy.loop = false
	return copy
