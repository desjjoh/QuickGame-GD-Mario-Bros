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


`landing_rejump_test` compares 20 flat-ground cases with a fresh Mesen-derived fixture: Small/Super, both travel directions, immediate versus one-ground-tick-delayed re-jumps, tapped/held Jump, and landing-contact press/hold rejection. It checks initial velocity, takeoff tick, early horizontal samples, apex within 1.1 pixels, and one integration per tick. See [phase 2 evidence](archive/base-movement-audit.md). No modern input buffering is expected.

`super_mario_corner_test` covers standing head penetration during diagonal apex entry in both directions, the last upward step before gravity reverses velocity, and thin upper obstructions. See [corner investigation and audit](archive/super-mario-corner-investigation.md) for verification limits.

`canvas_terrain_test` runs 48 seeded trajectories across default/game-canvas hierarchies, both directions, ground/brick/active-question/used-question fixtures, and three contact heights. It checks head gating, sideways stop versus head-only travel, distinct bounce/solid response, no Y snap, natural clearance, and exactly-once coin rewards. The terrain fixture clears inherited floating geometry before placing its floor.

`window_render_test` requires a rendered window and explicitly skips headless execution. It verifies all shadow styles and aspect-fitted image dimensions at 768×720, 1024×960, and 1000×700.

`enemy_canvas_test` verifies real Super hurtbox overlaps and block-to-Goomba/Koopa shape-query hits under both default and game-style canvases. Evidence and the separate existing block-bump test failure are recorded in [enemy canvas audit](archive/enemy-canvas-audit.md).

`brick_neighbor_test` uses 20 full grounded-jump cases with original-game break-event data. It compares recorded post-break integer heights/speed and directional outcomes, prevents repeated reactions for 16 physics ticks, and verifies gate expiry. It uses earlier controlled-court event data.

`vertical_fraction_test` compares 313 captured Mesen integration steps exactly across integer Y, speed, speed fraction and position fraction. `vertical_jump_reference_test` verifies the six-frame normal Super jump approach and its fractions against the controller-only trace, under a CanvasLayer, including the recorded shatter continuation and descent. See [vertical arithmetic verification](archive/vertical-movement-component.md).

`brick_seam_reference_test` checks 182 frames from 14 controller-only Mesen running/seam shatters, with exact logical Y, integer speed and both fractions. It replays observed horizontal positions to isolate vertical/collision behavior; horizontal simulation is checked separately by the full-jump neighbor regression.

`brick_debris_test` checks all three themed fragment atlases, initial two-pair trajectories, the 32-frame non-positional shatter cue at default gain/pitch, pause, and cleanup below the visible screen. `brick_break_test` checks the direct 50-point award and duplicate-hit rejection; brick debris creates no score popup. Compare fragment appearance and the combined bonk/shatter sound in a rendered playtest before claiming visual/audio parity.
