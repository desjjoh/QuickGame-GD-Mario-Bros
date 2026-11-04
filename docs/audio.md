# Sound effect mix

The shared playback mix lives in `assets/audio/sound_effect_mix.tres`. Open that Resource in Godot's Inspector to adjust Master Volume Db or the per-stream dictionary. BaseEntity applies the profile to state/action effects before playback. BaseLevel applies the same profile to its non-positional death player. This does not create an autoload, add an audio bus, or change source recordings, import settings or Project Settings.

## Current balance

| Sound | Per-stream trim | Effective playback gain with master -3 dB |
| --- | --- | --- |
| Small jump | 0 dB | -3 dB |
| Bump | -4 dB | -7 dB |
| Pipe | -1.5 dB | -4.5 dB |
| Repeated skid | -3.5 dB | -6.5 dB |
| Death jingle | -5 dB | -8 dB |

Unknown effects receive the shared master gain without a per-stream trim. Negative dB values reduce level; zero trim keeps the source relative to master. Master changes all these paths together. Area soundtrack playback remains disabled/deferred; this profile does not normalize the unused music files.

## Basis and limits

Decoded the five active assets through Godot playback at 44,100 Hz and measured source peak/average levels. Approximate active-sample RMS values before playback trims were jump -21.39 dBFS, bump -17.32, pipe -20.00 and death -16.27. Active samples here exclude magnitudes below one percent of that recording's peak; this is an engineering estimate, not a standardized perceptual loudness measurement. The skid's entire recording averaged -22.20 dBFS but its first 100ms averaged -18.06; repeated gameplay restarts that first burst every six 60Hz ticks. Its trim uses that audible burst rather than the full-file average. After trims, these estimates cluster around -24.3 to -24.6 dBFS including the master gain.

Measurements guide the initial pass; different pitch, timbre, envelopes and repeated exposure still affect perceived loudness. The death jingle retains its musical dynamics. Existing positional entity attenuation is unchanged, while the death jingle remains non-positional. Speaker/headphone audition is needed for final preference tuning. No EQ, compression, pitch change, resampling or gameplay timing change was introduced.

## Runtime copies and lifecycle

Loop-disabled private copies are made through `SoundEffectMix.one_shot_copy`. It retains the original source path in runtime metadata so the dictionary still matches bumps, skids and pipe sounds after duplication. Nested copies keep that identity. Original resources and imports stay intact. Death resolves its gain from the original death_sound before playing its private one-shot copy.

Starting another entity SFX still cancels its previous SFX. Slide exits still stop skidding; repeated skid requests use identical gains. The mix does not alter collision reactions, animation synchronization, death completion or transport gating.

## Verification and listening

sound_mix_test checks actual playback gains for all active sources and nested copies, original durations, one-shot loops, pitch, cancellation, repeated skid requests, the pipe state's private copy and BaseLevel death audio. Existing jump, slide, pipe and death regressions exercise their gameplay paths. Automated checks establish gain application, not subjective sound quality.

Local previews are `.godot/validation/sfx-original-preview.wav` and `sfx-balanced-preview.wav`. Both play jump, bump, pipe, six 100ms skid bursts, then death, with equal pauses. They use decoded recordings and playback gain equivalents, not spatial attenuation or the complete gameplay mix. Previews are ignored validation artifacts, not shipping assets.
