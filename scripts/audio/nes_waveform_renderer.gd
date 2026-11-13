extends RefCounted
## Renders NES-style pulse and long-mode noise to mono PCM.

const SAMPLE_RATE := 44100
const SAMPLES_PER_FRAME := 735
const CPU_HZ := 1789773.0


static func pulse(
	peak_sample: int,
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
			var amplitude := roundi(peak_sample * gain)
			pcm.encode_s16(offset + sample * 2, amplitude if phase < duty else -amplitude)
			phase = fposmod(phase + phase_step, 1.0)
	return pcm_stream(pcm)


# Render pulse control and sweep changes on a nominal 60 Hz clock.
static func swept_pulse(
	peak_sample: int,
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
			var amplitude := roundi(peak_sample * volume / 15.0) if period >= 8 else 0
			pcm.encode_s16(offset + sample * 2, amplitude if phase < duty else -amplitude)
			phase = fposmod(phase + CPU_HZ / (16.0 * (period + 1) * SAMPLE_RATE), 1.0)
	return pcm_stream(pcm)


static func pcm_stream(pcm: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = pcm
	return stream


## The frame count includes trailing silence after the envelope.
static func noise(
	period_cycles: int,
	noise_peak: float,
	envelope: Array[int],
	frame_lengths: Array[int],
	frame_count: int
) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	pcm.resize(frame_count * SAMPLES_PER_FRAME * 2)
	var register := 1
	var noise_phase := 0.0
	var phase_step := CPU_HZ / (float(period_cycles) * SAMPLE_RATE)
	var sample := 0
	for index in range(envelope.size()):
		var amplitude := roundi(noise_peak * envelope[index] / 15.0)
		var ticks := frame_lengths[index]
		for _sample_in_step in range(ticks * SAMPLES_PER_FRAME):
			noise_phase += phase_step
			if noise_phase >= 1.0:
				noise_phase -= 1.0
				var feedback := (register ^ (register >> 1)) & 1
				register = (register >> 1) | (feedback << 14)
			pcm.encode_s16(sample * 2, amplitude if (register & 1) == 0 else -amplitude)
			sample += 1
	return pcm_stream(pcm)
