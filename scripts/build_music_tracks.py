"""Render event jingles as mono PCM from their NES note and length data."""
from math import floor
from pathlib import Path
import struct
import wave


SAMPLE_RATE = 44100
SAMPLES_PER_FRAME = 735
CPU_HZ = 1789773
# Match the full-volume pulse scale in SoundHandler.
PULSE_PEAK = 5900
TRIANGLE_PEAK = round(PULSE_PEAK * 2300 / 3300)
PERIODS = (
    0x088, 0x02f, 0, 0x2a6, 0x280, 0x25c, 0x23a, 0x21a,
    0x1df, 0x1c4, 0x1ab, 0x193, 0x17c, 0x167, 0x153, 0x140,
    0x12e, 0x11d, 0x10d, 0x0fe, 0x0ef, 0x0e2, 0x0d5, 0x0c9,
    0x0be, 0x0b3, 0x0a9, 0x0a0, 0x097, 0x08e, 0x086, 0x077,
    0x07e, 0x071, 0x054, 0x064, 0x05f, 0x059, 0x050, 0x047,
    0x043, 0x03b, 0x035, 0x02a, 0x023, 0x475, 0x357, 0x2f9,
    0x2cf, 0x1fc, 0x06a,
)
NORMAL_LENGTHS = (54, 3, 9, 6, 18, 27, 36, 12)
CLEAR_LENGTHS = (36, 2, 6, 4, 12, 18, 24, 8)
CASTLE_CLEAR_LENGTHS = (4, 8, 16, 32, 64, 24, 48, 12)
CASTLE_CLEAR_PULSE_CONTROLS = (0x90, 0x9b, 0x9a, 0x99, 0x98)
HURRY_JINGLE_LENGTHS = (3, 6, 12, 24, 48, 18, 36, 8)
EVENT_PULSE_VOLUME = (
    0, 1, 2, 2, 3, 3, 3, 4,
    4, 4, 4, 4, 4, 5, 5, 5,
    5, 5, 5, 6, 6, 6, 6, 6,
    6, 6, 6, 6, 6, 6, 6, 6,
    6, 6, 6, 6, 5, 5, 4, 3,
)
# Hurry's first note frame reads one byte beyond the event envelope table.
HURRY_PULSE_CONTROLS = (0x15, *(0x90 | volume for volume in reversed(EVENT_PULSE_VOLUME)))
PULSE_DUTIES = (0.125, 0.25, 0.5, 0.75)
# The area counter starts at 8, immediately after the eight-entry area table.
AREA_PULSE_VOLUME = (0, 4, 4, 5, 5, 6, 7, 8, 0)
TRACKS = {
    "castle_clear": (
        CASTLE_CLEAR_LENGTHS,
        "81 2c 22 1c 2c 22 1c 85 2c 04 81 2e 24 1e 2e 24 1e 85 2e 04 "
        "81 32 28 22 32 28 22 85 32 87 36 36 36 84 3a",
        "5c 54 4c 5c 54 4c 5c 1c 1c 5c 5c 5c 5c 5e 56 4e 5e 56 4e "
        "5e 1e 1e 5e 5e 5e 5e 62 5a 50 62 5a 50 62 22 22 62 e7 e7 e7 2b",
        "86 14 81 14 80 14 14 81 14 14 14 14 86 16 81 16 80 16 16 81 16 16 16 16 "
        "81 28 22 1a 28 22 1a 28 80 28 28 81 28 87 2c 2c 2c 84 30",
    ),
    "stage_clear": (
        CLEAR_LENGTHS,
        "87 04 06 0c 14 1c 22 86 2c 22 87 04 60 0e 14 1a 24 86 2c 24 "
        "87 04 08 10 18 1e 28 86 30 30 80 64",
        "cd d5 dd e3 ed f5 bb b5 cf d5 db e5 ed f3 bd b3 d1 d9 df e9 f1 f7 bf ff ff ff 34",
        "86 04 87 14 1c 22 86 34 84 2c 04 04 04 87 14 1a 24 86 32 84 2c 04 "
        "86 04 87 18 1e 28 86 36 87 30 30 30 80 2c",
    ),
    "death": (
        NORMAL_LENGTHS,
        "86 04 82 2a 36 04 36 87 36 34 30 86 2c 04",
        "68 6a 6c 45 a2 31 b0 f1 ed eb a2 1d 9c 95",
        "86 04 85 22 82 22 87 22 26 2a 84 2c 22 86 14",
    ),
    "game_over": (
        NORMAL_LENGTHS,
        "82 2c 04 04 22 04 04 84 1c 87 26 2a 26 84 24 28 24 80 22",
        "9c 05 94 05 0d 9f 1e 9c 98 9d",
        "82 22 04 04 1c 04 04 84 14 86 1e 80 16 80 14",
    ),
}
HURRY_JINGLE = (
    "81 1c 30 04 30 30 04 1e 32 04 32 32 04 20 34 04 34 34 04 36 04 84 36",
    "46 a4 64 a4 48 a6 66 a6 4a a8 68 a8 6a 44 2b",
    "81 2a 42 04 42 42 04 2c 64 04 64 64 04 2e 46 04 46 46 04 22 04 84 22",
)


def decode(data, lengths, packed=False):
    duration = lengths[0]
    for value in bytes.fromhex(data):
        if packed:
            index = ((value >> 6) & 3) | ((value & 1) << 2)
            yield value & 0x3e, lengths[index]
        elif value >= 128:
            duration = lengths[value & 7]
        else:
            yield value, duration


def castle_clear_melody(notes):
    melody = []
    for note, frames in notes:
        if note == 0x04:
            # The rest byte leaves the pulse period alone. The castle-clear
            # envelope immediately writes $98, keeping the previous tone audible.
            previous_note, previous_frames = melody[-1]
            melody[-1] = (previous_note, previous_frames + frames)
        else:
            melody.append((note, frames))
    return melody


def render(
    notes, samples, triangle=False, death=False, sweep=False, area=False, controls=(),
    sustain_long_triangle=False, short_triangle_counter=31,
):
    output = [0.0] * samples
    offset = 0
    for note, frames in notes:
        count = frames * SAMPLES_PER_FRAME
        audible_count = count
        sustained = sustain_long_triangle and frames >= 18
        if triangle and not death and not sustained and (area or frames < 18):
            audible_count = min(count, short_triangle_counter * SAMPLES_PER_FRAME // 4)
        period = PERIODS[note // 2]
        if period and offset < samples:
            rate = CPU_HZ / ((32 if triangle else 16) * (period + 1))
            phase = 0.0
            for index in range(min(audible_count, samples - offset)):
                if sweep and index and index % SAMPLES_PER_FRAME == 0:
                    # Death music writes the alternate positive sweep to Square 1.
                    period += period >> 4
                    rate = CPU_HZ / (16 * (period + 1))
                if not death:
                    phase = index * rate / SAMPLE_RATE
                    phase -= floor(phase)
                edge = min(1.0, index / 48, (audible_count - index) / 48)
                if triangle:
                    value = (1.0 - 4.0 * abs(phase - 0.5)) * TRIANGLE_PEAK
                    if death and index * 4 >= 31 * SAMPLES_PER_FRAME:
                        value = 0.0
                else:
                    duty = 0.5
                    if death:
                        # The death event uses hardware decay instead of the music envelope table.
                        step = index * 4 // (3 * SAMPLES_PER_FRAME)
                        envelope = max(0.0, (15 - step) / 15.0)
                    elif controls:
                        control = controls[min(len(controls) - 1, index // SAMPLES_PER_FRAME)]
                        envelope = (control & 0x0F) / 15.0
                        duty = PULSE_DUTIES[control >> 6]
                    else:
                        volumes = AREA_PULSE_VOLUME if area else EVENT_PULSE_VOLUME
                        table_index = max(0, len(volumes) - 1 - index // SAMPLES_PER_FRAME)
                        envelope = volumes[table_index] / 15.0
                    value = (1 if phase < duty else -1) * PULSE_PEAK * envelope
                output[offset + index] = value * edge
                if death:
                    phase = (phase + rate / SAMPLE_RATE) % 1.0
        offset += count
    return output


EVENT_LEVEL_CORRECTIONS_DB = {
    "castle_clear": -9.27,
    "stage_clear": -7.92,
    "death": -9.78,
    "game_over": -6.75,
}
HURRY_LEVEL_SCALE = 10 ** (-6.35 / 20)


def main():
    folder = Path(__file__).resolve().parents[1] / "assets" / "audio" / "music"
    folder.mkdir(parents=True, exist_ok=True)
    for name, (lengths, melody, harmony, bass) in TRACKS.items():
        notes = list(decode(melody, lengths))
        castle_clear = name == "castle_clear"
        if castle_clear:
            notes = castle_clear_melody(notes)
        count = sum(frames for _, frames in notes) * SAMPLES_PER_FRAME
        death = name == "death"
        controls = CASTLE_CLEAR_PULSE_CONTROLS if castle_clear else ()
        voices = (
            render(notes, count, death=death, controls=controls),
            render(
                decode(harmony, lengths, packed=True), count,
                death=death, sweep=death, controls=controls,
            ),
            render(
                decode(bass, lengths), count, triangle=True, death=death,
                short_triangle_counter=15 if castle_clear else 31,
            ),
        )
        scale = 10 ** (EVENT_LEVEL_CORRECTIONS_DB[name] / 20)
        if name == "stage_clear":
            write_track(folder / "stage_clear_pulse.wav", (voices[0],), scale=scale)
            voices = voices[1:]
        write_track(folder / f"{name}.wav", voices, scale=scale)
    melody, harmony, bass = HURRY_JINGLE
    pulse_two = list(decode(melody, HURRY_JINGLE_LENGTHS))
    frames = sum(duration for _, duration in pulse_two)
    assert frames == 168
    count = frames * SAMPLES_PER_FRAME
    write_track(
        folder / "hurry_up_pulse_two.wav",
        (render(pulse_two, count, controls=HURRY_PULSE_CONTROLS),),
        scale=HURRY_LEVEL_SCALE,
    )
    pulse_one = decode(harmony, HURRY_JINGLE_LENGTHS, packed=True)
    write_track(
        folder / "hurry_up_pulse_one.wav",
        (render(pulse_one, count, controls=HURRY_PULSE_CONTROLS),),
        scale=HURRY_LEVEL_SCALE,
    )
    triangle = decode(bass, HURRY_JINGLE_LENGTHS)
    write_track(
        folder / "hurry_up_triangle.wav",
        (render(triangle, count, triangle=True),),
        scale=HURRY_LEVEL_SCALE,
    )


def scale_pcm_samples(samples, scale):
    return b"".join(struct.pack("<h", round(sample * scale)) for sample in samples)


def write_track(path, voices, *, scale=1.0):
    pcm = scale_pcm_samples((round(sum(sample)) for sample in zip(*voices)), scale)
    with wave.open(str(path), "wb") as stream:
        stream.setparams((1, 2, SAMPLE_RATE, 0, "NONE", "not compressed"))
        stream.writeframes(pcm)



if __name__ == "__main__":
    main()
