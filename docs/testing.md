# Testing

## Run regression scenes

From the project root in PowerShell, run:

```powershell
./scripts/run_tests.ps1 -GodotPath 'C:\path\to\Godot_console.exe'
```

The runner discovers `tests/*_test.tscn` and writes logs under `.godot/validation`. It requires a PASS marker and a successful exit, and treats errors and warnings as failures. To investigate one scenario, run its scene directly with the Godot console executable:

```powershell
& 'C:\path\to\Godot_console.exe' --headless --path . res://tests/transition_test.tscn --max-fps 60 --quit-after 1800
```

## Manual checks

- Press Start while jumping, during enemy movement, and while a block releases an item. Check that gameplay and music freeze, the pause cue plays, and a fresh Start resumes without jumping. Repeat in F6. Listen to pause/resume against Mesen.
- Start 1-1 from the title, enter and exit the secret area, and verify camera, theme, HUD, and music handoffs.
- Test jumping and running with keyboard and controller. Check pipe and ledge contacts, especially at high refresh rates.
- Die in a pit and by timeout. Verify life loss, progress policy, restart, and return to title after game over.
- Bonk a painted question block in-game and check the immediate HUD reward, coin arc, and floating 200. Revisit the used block and verify it grants no second reward.
- Finish at the flagpole. Check the score popup, time conversion, music, and castle flag.
- Finish with timer endings 1, 3, and 6 and check the corresponding castle bursts, blast sounds, and 500 points per burst. Other final digits produce none. Pause during a burst and verify its frame and score remain frozen.
- Compare generated audio with Mesen at the same playback level. Check note period, duty cycle, attack, decay, cutoff, and retrigger timing before changing pitch or gain. Area loops and jingles use different envelope rules.

Headless regressions check playback routing and lifecycle. Use a rendered run and listening comparison for frame pacing and audio fidelity. See [backlog](backlog.md) for known verification gaps.


For Super Mario integration, run super_mario_movement_test and mario_form_test. The pipe_entry, pipe_transfer, sideways_pipe, climbing, and flagpole_ending scenes also accept `-- --super` after the scene path to exercise their existing checks with Super configuration. Original-game trace reproduction and evidence boundaries are recorded in [Super movement and posture](archive/super-mario-movement.md).


## Deterministic audio teardown

Successful regression exits call `await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())` after their assertions and normal scene cleanup. The helper stops remaining non-positional audio players and waits for two observed AudioServer mix boundaries, with a one-second timeout. Fixed-FPS scene frames are not evidence that the independent audio thread has advanced. A one-millisecond cooperative pacing step prevents accelerated tests from exhausting their frame limit during the wait. Timeout reports an error and exits unsuccessfully; warnings are not filtered or suppressed. The helper quiesces test callbacks and pauses the test tree during final teardown only; shipped gameplay and exit behavior are unchanged.

Run a selected set without invoking the full suite:

```powershell
./scripts/run_tests.ps1 -GodotPath 'C:\path\to\Godot_console.exe' -TestName @('audio_shutdown_test', 'shell_kick_score_test', 'sound_mix_test')
```

Names must match scene basenames. The runner accepts both `PASS:` and `<scene>_test: PASS` markers and still requires a successful process exit with no errors or warnings. The audio_shutdown regression verifies that weak references to stopped streams and playback objects actually become invalid. See the [shutdown investigation](archive/shutdown-investigation.md) for the reproduction, evidence, and remaining native-failure scope.


`down_direction_test` covers both forms and both horizontal directions: grounded diagonal cancellation, stationary holds, momentum with and without Run, opposing-direction and Down-only low-speed stops, crouch release, jump availability, and airborne steering. `super_mario_movement_test` retains crouch-jump/release/landing coverage.


`enemy_boundary_test` checks enemy activation column rounding and one-pixel thresholds, left/right anchor cleanup, actual actor disposal, and simultaneous 24-pixel-spaced group activation/movement. `enemy_spawn_test` retains cap/skipped-attempt and area-reload checks; `nested_entity_activity_test` covers moving actors and shells independently of sleeping placements.


`shell_spawn_contact_test` exercises a right-edge pair with a temporarily unavailable target: rejected shell hits remain retryable, accepted hits award once, and overlap cannot duplicate chain points. This is a controlled rejection fixture; the reported natural pair-entry failure remains unconfirmed. See [contact investigation](archive/shell-entry-contact-audit.md).


`shadow_style_test` checks Game-wide Soft/Crisp/Outer Blur/null selection, persistence through level replacement, and standalone preview composition, including blank startup, restoration, buffer bypass, and unchanged decoration ownership. Standalone startup checks the authored Game default. Run it with a display to verify foreground sharpness, decoration exclusion, crisp offset, and symmetric outer blur pixels. `koopa_shadow_test` is a rendered-only comparison of both walking poses at integer positions across all styles; its headless path skips image assertions. A half-pixel compositor/direct rasterization discrepancy remains an investigation item; see [shadow styles](archive/shadow-styles.md).


`camera_arrival_test` runs an actual 1-1 lower-area-to-overworld animated pipe return and asserts NES sprite-origin X=56/body X=64, idle stability, and no delayed scroll after a recorded placement correction. `corner_correction_test` checks that real head escapes do not move the camera and subsequent walking still does. Super movement checks account for stationary push-out; camera wall-hop and ledge matrices cover blocked contacts versus valid landing motion.


`area_background_test` checks standalone preview colour, camera-bound fill geometry, transparent fallback, offset-area loading/routing, and disabled-shadow behavior. Its rendered checks also verify visible bounds, foreground order, and shadows landing on the fill without the fill casting its own shadow.
