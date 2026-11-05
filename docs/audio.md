# Sound effect mix

The shared playback mix lives in `assets/audio/sound_effect_mix.tres`. Open that Resource in Godot's Inspector to adjust Master Volume Db or the per-stream dictionary. BaseEntity applies the profile to state/action effects before playback. BaseLevel applies the same profile to its non-positional death player. This does not create an autoload, add an audio bus, or change source recordings, import settings or Project Settings.

## Current balance

| Sound | Per-stream trim | Effective playback gain with master -3 dB |
| --- | --- | --- |
| Small jump | 0 dB | -3 dB |
| Bump | -4 dB | -7 dB |
| Pipe | -1.5 dB | -4.5 dB |
| Flag lowering | -2 dB | -5 dB |
| Stage-clear music | -3 dB | -6 dB |
| Death jingle | -5 dB | -8 dB |
| Game-over jingle | -5 dB | -8 dB |

Unknown effects receive the shared master gain without a per-stream trim. Negative dB values reduce level; zero trim keeps the source relative to master. Master changes all these paths together. Area soundtrack playback remains disabled/deferred; this profile does not normalize the unused music files.

## Basis and limits

The initial balance analysis decoded the then-active assets through Godot playback at 44,100 Hz and measured source peak/average levels. Approximate active-sample RMS values before playback trims were jump -21.39 dBFS, bump -17.32, pipe -20.00 and death -16.27. Active samples here exclude magnitudes below one percent of that recording's peak; this is an engineering estimate, not a standardized perceptual loudness measurement. The skid's entire recording averaged -22.20 dBFS but its first 100ms averaged -18.06; repeated gameplay restarts that first burst every six 60Hz ticks. Its trim uses that audible burst rather than the full-file average. The initial trims clustered these estimates around -24.3 to -24.6 dBFS including the master gain. Following user listening feedback that skidding was too quiet, its trim was raised by 6 dB (from -3.5 to +2.5 dB); other effects retain their original balance. The current skid gain deliberately departs from that initial measurement target.

Measurements guide the initial pass; different pitch, timbre, envelopes and repeated exposure still affect perceived loudness. The death jingle retains its musical dynamics. Existing positional entity attenuation is unchanged, while the death jingle remains non-positional. Speaker/headphone audition is needed for final preference tuning. No EQ, compression, pitch change, resampling or gameplay timing change was introduced.

## Runtime copies and lifecycle

Loop-disabled private copies are made through `SoundEffectMix.one_shot_copy`. It retains the original source path in runtime metadata so the dictionary still matches bumps and pipe sounds after duplication. Nested copies keep that identity. Original resources and imports stay intact. Death resolves its gain from the original death_sound before playing its private one-shot copy.

Starting another entity SFX still cancels its previous SFX. Sliding is silent: its Lost Levels-style repeat playback and scene/mix references were removed at the user's request. The source MP3 remains unused for possible later revisiting. The mix does not alter collision reactions, animation synchronization, death completion or transport gating.

## Verification and listening

sound_mix_test checks actual playback gains for all active sources and nested copies, original durations, one-shot loops, pitch, cancellation, the pipe state's private copy and BaseLevel death audio. Existing jump, slide, pipe and death regressions exercise their gameplay paths. Automated checks establish gain application, not subjective sound quality.

Local previews are `.godot/validation/sfx-original-preview.wav` and `sfx-balanced-preview.wav`. Both play jump, bump, pipe, six 100ms skid bursts, then death, with equal pauses. These historical previews include the now-disabled skid sound and do not represent the current active mix. They use decoded recordings and playback gain equivalents, not spatial attenuation or the complete gameplay mix. Previews are ignored validation artifacts, not shipping assets.

GameOver presentation owns the non-positional smb_gameover.wav one-shot independently of the departing level. It uses the shared mix and stops on cancellation/removal. Stage completion waits for its finished state, with minimum presentation frames and bounded fallback. This trim follows the death-jingle policy and has not been subjectively normalized through speaker audition.

## Flagpole ending audio

FlagpoleEndingPresentation plays smb_flagpole.wav on accepted contact, then replaces it with smb_stage_clear.wav at the scripted walk cue. Both use runtime one-shot copies and the shared mix; preceding player SFX are stopped at contact. The level-owned audio survives Mario's endpoint shutdown/removal. After the score/fireworks hooks and stage-clear playback finish, the final 126-tick hold runs before completion. This is event music only; deferred area background music is not re-enabled.

## Ending balance refinement (2026-11-05)

The two new ending sounds previously fell back to master-only gain. Source PCM measurements gave active-sample RMS of approximately -20.68 dBFS for smb_flagpole.wav and -18.29 dBFS for smb_stage_clear.wav, compared with jump -21.37 and death -16.24 before trims. The stage-clear trim is now -3 dB, giving approximately -24.29 dBFS after master, close to the existing target. Flag lowering uses -2 dB, approximately -25.68 dBFS after master, allowing an additional margin for its reported sharp/loud character. These are active-sample engineering estimates, not LUFS/perceptual normalization. Only the shared playback gain Resource changed; source samples, pitch, timing, loop/import settings and other gains remain intact.
