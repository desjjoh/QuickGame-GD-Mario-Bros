# Shutdown and ObjectDB investigation

Date: 2026-11-07. Scope: reported headless-regression ObjectDB warnings. Native shutdown failure remains a separate, unreproduced issue.

## Findings

Verbose Godot 4.7.2 logs identified AudioStreamWAV and AudioStreamPlaybackWAV survivors, rather than leaked enemy/player nodes, in the selected scenes. mario_form initially reported two instances; shell_kick_score reported 21; sound_mix reported 22. Some identical scene reruns produced no warnings. This pattern alone suggested timing, but did not establish a cause.

A minimal ignored diagnostic scene then created 16 new AudioStreamWAV/AudioStreamPlayer pairs, called play(), stop(), and free() on every player, and exited immediately. It reproduced 32 leaked stream/playback instances without invoking any gameplay/level/player code. Running the same reproduction with a real-time audio-thread cleanup opportunity exited cleanly. An initial fixed-FPS diagnostic attempt exhausted its quit-after frame cap before the wall-time wait completed; that run was not counted as a successful drain. The completed comparison used max-fps 60.

The evidence isolates deferred AudioServer playback release at process exit for these warnings. Scene/process frames, especially accelerated fixed-FPS frames, do not guarantee an audio mix boundary. A larger audio-resource count in a test that repeatedly creates/frees voices does not by itself imply a gameplay actor leak. This does not rule out other leaks in untested code.

Related upstream reports document audio-server-held references at shutdown: [Godot #76745](https://github.com/godotengine/godot/issues/76745) and [Godot #95484](https://github.com/godotengine/godot/issues/95484). These are supporting context, not proof that every historical project warning or crash has the same cause. The local minimal reproduction establishes the observed 4.7.2 behavior.

## Fix boundary

Added tests/fixtures/finish_test.gd. Successful test exits now use a shared test-only completion path; explicit failure exits remain immediate. The helper guards repeated finish requests, disables the test root's frame callbacks, pauses the test tree, recursively stops remaining AudioStreamPlayer voices, and waits for two decreases in AudioServer.get_time_since_last_mix(). Those decreases indicate observed audio mix boundaries. It uses a bounded one-second monotonic deadline and a one-millisecond pacing step while yielding process frames. This avoids interpreting simulated game time as audio-thread progress and avoids consuming a short fixed-FPS quit-after budget while waiting.

A timeout emits an error and exits with code 1. It never suppresses ObjectDB warnings or alters stream pitch, volume, positional behavior, or generated PCM. Original scene-specific cleanup still runs before completion. Pausing/quiescing happens only after assertions in tests; no runtime game shutdown coordinator, delay, or project setting was added. No audio ownership code was changed on the strength of engine-held references alone.

Migrated the existing 80 test scripts that had successful get_tree().quit() exits to the shared helper, including early successful headless skips. Added audio_shutdown_test, which creates and frees 16 voices and uses weak references to verify all stream/playback objects are released after draining. This is a release assertion, not merely a test that its own output contains no warning. The full suite was not run; the migration was a mechanical shared-exit change, with focused runtime validation below.

Updated run_tests.ps1 with optional -TestName scene-basename selection so focused verification does not require the full suite. Unknown names fail rather than silently running nothing. The runner now recognizes the newer scene_name_test: PASS convention as well as PASS:. Existing process-exit/error/warning checks remain strict, and selected runs are labelled selected rather than all.

## Verification

Initial fixed-FPS verbose runs of mario_form, shell_kick_score, sound_mix, and super_mario_movement passed their assertions and exited cleanly after the helper was added. The final audio_shutdown weak-reference check also passed at accelerated fixed FPS.

The strict runner selected animation_clock, audio_shutdown, death, mario_form, pause, shell_kick_score, sideways_pipe, sound_mix, super_mario_movement, and title_backdrop: all ten reached PASS with successful exits and no engine errors or warnings. After adding teardown reentry/quiescing safeguards, a focused follow-up of audio_shutdown, pause, shell_kick_score, slide_collision, and sound_mix again passed without errors or warnings. These are overlapping focused sets, not a full-suite run. The slide collision test exercises a successful exit from a physics callback; pause exercises the always-processing audio cue, and animation_clock runs in real time.

Native shutdown failures were not reproduced during these checks; no native crash fix is claimed. Full regression qualification, exported-build shutdown, and ordinary interactive window-close behavior were not tested in this pass. Existing historical warning entries are preserved. All diagnostic logs and the minimal reproduction remain under ignored .godot/validation. No AGENTS.md, project settings, Input Map, import settings, gameplay, or runtime shutdown behavior changed for this fix.
