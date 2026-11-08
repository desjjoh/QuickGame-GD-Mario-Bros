"""Render the area loops using the existing pulse and triangle renderer."""
from pathlib import Path
import struct
import wave

from build_music_tracks import (
    CPU_HZ,
    NORMAL_LENGTHS,
    PULSE_PEAK,
    SAMPLE_RATE,
    SAMPLES_PER_FRAME,
    decode,
    render,
)


GROUND = {
    "lead": [
        "82 34 84 34 34 82 2c 84 34 86 3a 04 00",
        "a0 21 21 a0 21 2b 05 a3",
        "82 18 84 18 18 82 18 18 04 86 3a 22"
    ],
    "p1": [
        "85 2c 22 1c 84 26 2a 82 28 26 04 87 22 34 3a 82 40 04 36 84 3a 34 82 2c 30 85 2a 00",
        "5d 55 4d 15 19 96 15 d5 e3 eb 2d a6 2b 27 9c 9e 59",
        "85 22 1c 14 84 1e 22 82 20 1e 04 87 1c 2c 34 82 36 04 30 34 04 2c 04 26 2a 85 22"
    ],
    "p2a": [
        "84 04 82 3a 38 36 32 04 34 04 24 26 2c 04 26 2c 30 00",
        "05 b4 b2 b0 2b ac 84 9c 9e a2 84 94 9c 9e",
        "85 14 22 84 2c 85 1e 82 2c 84 2c 1e"
    ],
    "p2b": [
        "84 04 82 3a 38 36 32 04 34 04 64 04 64 86 64 00",
        "05 b4 b2 b0 2b ac 84 37 b6 b6 45",
        "85 14 1c 82 22 84 2c 4e 82 4e 84 4e 22"
    ],
    "p2c": [
        "84 04 85 32 85 30 86 2c 04 00",
        "05 a4 05 9e 05 9d 85",
        "84 14 85 24 28 2c 82 22 84 22 14"
    ],
    "p3a": [
        "82 2c 84 2c 2c 82 2c 30 04 34 2c 04 26 86 22 00",
        "a4 25 25 a4 29 a2 1d 9c 95",
        "85 0e 1a 84 24 85 22 14 84 0c 82 34"
    ],
    "p3b": [
        "82 2c 2c 04 2c 04 2c 30 85 34 04 04 00",
        "a4 25 25 a4 a8 63 04",
        "85 0e 1a 84 24 85 22 14 84 0c"
    ],
    "p4a": [
        "82 34 84 2c 85 22 84 24 82 26 36 04 36 86 26 00",
        "ac 27 5d 1d 9e 2d ac 9f",
        "85 14 82 20 84 22 2c 1e 1e 82 2c 2c 1e 04"
    ],
    "p4b": [
        "87 2a 40 40 40 3a 36 82 34 2c 04 26 86 22 00",
        "e3 f7 f7 f7 f5 f1 ac 27 9e 9d",
        "85 18 82 1e 84 22 2a 22 22 82 2c 2c 22 04"
    ],
    "p4c": [
        "82 2a 36 04 36 87 36 34 30 86 2c 04 00 00 68 6a 6c 45",
        "a2 31 b0 f1 ed eb a2 1d 9c 95 86 04",
        "85 22 82 22 87 22 26 2a 84 2c 22 86 14"
    ]
}
GROUND_BEATS = {
    "p1": "21 d0 c4 d0 31 d0 c4 d0",
    "p2a": "21 d0 c4 d0 31 d0 c4 d0",
    "p2b": "21 d0 c4 d0 31 d0 c4 d0",
    "p2c": "21 d0 c4 d0 31 d0 c4 d0",
    "p3a": "31 90 31 90 31 71 31 90 90 90",
    "p3b": "31 90 31 90 31 71 31 90 90 90",
    "lead": "31 90 31 90 31 71 31 90 90 90",
    "p4a": "51 90 31 11",
    "p4b": "51 90 31 11",
    "p4c": "51 90 31 11"
}
# Compare the noise and pulse weights at the same hardware volume.
NOISE_SAMPLE = round(PULSE_PEAK * (12 / 15) * (0.00494 / 0.00752) / 2)
GROUND_ORDER = (
    "lead p1 p1 p2a p2b p2a p2c p2a p2b p2a p2c p3a p3b p3a lead "
    "p1 p1 p4a p4b p4a p4c p4a p4b p4a p4c p3a p3b p3a lead p4a p4b p4a p4c"
)
UNDERGROUND = (
    "82 14 2c 62 26 10 28 80 04 82 14 2c 62 26 10 28 80 04 "
    "82 08 1e 5e 18 60 1a 80 04 82 08 1e 5e 18 60 1a 86 04 "
    "83 1a 18 16 84 14 1a 18 0e 0c 16 83 14 20 1e 1c 28 26 "
    "87 24 1a 12 10 62 0e 80 04 04"
)


def render_noise(pattern, count):
    output = [0] * count
    beats = list(decode(pattern, NORMAL_LENGTHS, packed=True))
    offset = 0
    register = 1
    clock = 0.0
    while offset < count:
        for beat, frames in beats:
            duration = frames * SAMPLES_PER_FRAME
            if beat in (0x10, 0x20, 0x30):
                period = 762 if beat == 0x20 else 32
                active_frames = 5 if beat == 0x30 else 1
                active = min(duration, active_frames * SAMPLES_PER_FRAME, count - offset)
                for sample in range(active):
                    clock += CPU_HZ / SAMPLE_RATE
                    while clock >= period:
                        feedback = (register ^ (register >> 1)) & 1
                        register = (register >> 1) | (feedback << 14)
                        clock -= period
                    edge = min(1.0, sample / 24, (active - sample) / 24)
                    output[offset + sample] = round(NOISE_SAMPLE * edge) * (
                        -1 if register & 1 else 1
                    )
            offset += duration
            if offset >= count:
                break
    return output


def render_section(melody, harmony, bass, beats=""):
    notes = list(decode(melody, NORMAL_LENGTHS))
    count = sum(frames for _, frames in notes) * SAMPLES_PER_FRAME
    voices = (
        render(notes, count, area=True),
        render(decode(harmony, NORMAL_LENGTHS, packed=True), count, area=True),
        render(decode(bass, NORMAL_LENGTHS), count, triangle=True, area=True),
    )
    if beats:
        voices += (render_noise(beats, count),)
    return b"".join(struct.pack("<h", round(sum(sample))) for sample in zip(*voices))


def main():
    folder = Path(__file__).resolve().parents[1] / "assets" / "audio" / "music"
    folder.mkdir(parents=True, exist_ok=True)
    ground = {
        name: render_section(melody.split(" 00", 1)[0], harmony, bass, GROUND_BEATS[name])
        for name, (melody, harmony, bass) in GROUND.items()
    }
    tracks = {
        "overworld": (ground[part] for part in GROUND_ORDER.split()),
        "underground": (render_section(UNDERGROUND, "", UNDERGROUND),),
    }
    for name, sections in tracks.items():
        with wave.open(str(folder / f"{name}.wav"), "wb") as stream:
            stream.setparams((1, 2, SAMPLE_RATE, 0, "NONE", "not compressed"))
            for section in sections:
                stream.writeframesraw(section)


if __name__ == "__main__":
    main()

