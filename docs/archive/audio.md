# Audio

Sounds play at the audio player default gain. SoundHandler caches the generated cues and owns the shared reward voice. All audio playback is non-positional. Entity and transition players own their playback. Loop-disabled copies preserve the source stream.

## Level-clear timer tick

The timer conversion requests a synthesized 981 Hz, 50% duty pulse for four physics ticks out of every eight. The one-shot is 100 ms long and shares the coin and 1 UP playback voice, with 1 UP protected. Its PCM peak is about -15 dBFS.

Coin and 1 UP are also synthesized on the shared voice. Coin uses two tones over 53 frames with one continuous decay and a 50% duty cycle. 1 UP uses six eight-frame tones with a fresh envelope on each tone and a 50% duty cycle.

Power-up emergence requests the reveal cue on the same voice. It uses the NES reveal frequency sequence, with the previous note held through zero-frequency entries, over 31 nominal frames. The shared voice keeps its default playback gain and gives the 1 UP pickup cue priority.

## Jump and ceiling bump

Small Mario uses the jump_small and bump cues from SoundHandler. The generated streams approximate the original Square 1 pitch sweeps and volume changes on a 60 Hz timeline. They play through the existing player voice.

## Pipe entry and flagpole

SoundHandler generates the pipe entry cue from six swept pulse bursts and the flagpole cue from a descending-period pulse sweep. Pipe entry uses the player voice. The ending presentation plays the flagpole cue on its own voice.

## Event music

Stage clear, death, and game over each use a separate WAV under assets/audio/music. Run python scripts/build_music_tracks.py from the project root to regenerate them from note and duration data. The renderer approximates two pulse voices and a triangle voice. Death uses the alternate Square 1 pitch sweep and hardware-style pulse decay. The reference leaves its noise channel silent for this event. The existing ending, death, and game-over scenes own playback and completion timing.

Stage clear and game over step through the NES event pulse volume table at 60 Hz. Their short triangle notes use the 31-quarter-frame gate.

During stage clear, the second pulse plays from stage_clear_pulse.wav alongside the main track. Reward cues temporarily take over that pulse voice while both music timelines keep advancing. The timer tick uses its original-style decay.

All generated music and effects map a full-volume pulse to 5,900 PCM units. Music uses one triangle scale across tracks. Cue envelopes and the pulse takeover determine relative levels during playback.

## Background music

Set Background Music on a level area to Overworld, Underground, or None. MusicHandler starts its non-positional loop once the area is revealed. Any area transition stops and restarts the music, including a transition within the same area. A direct relocation within the same area keeps the loop playing. Death, completion, and level shutdown stop the loop. Test Level and the title backdrop are silent.

Run python scripts/build_area_music.py to regenerate the two loops. Their pulse and triangle arrangements use reference note data. Overworld includes the reference noise-channel rhythm. Underground uses the pitched voices alone, as in the reference.

Overworld and Underground use the area pulse envelope and triangle counter. Their note periods and playback rate are unchanged.

## Checking new sounds against the NES

When a cue sounds off-pitch, soft, or too sharp, compare it side by side with Mesen at the same playback level. First check the note periods and sample rate. Then check the channel waveform and duty cycle, attack and decay, note cutoff, and retrigger timing. For music, use the envelope and triangle counter rules for that track type. Area loops and event jingles can use the same pitches and still sound different.

Keep the shared PCM scale and default playback gain during this comparison. A headless playback test verifies that the cue reaches its player. The listening comparison verifies its sound.
