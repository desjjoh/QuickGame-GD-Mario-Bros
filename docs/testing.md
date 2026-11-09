# Testing

## Focused headless regressions

Run tests from the project root with a Godot 4.7 console executable. Local qualification uses Godot 4.7.2.

```powershell
./scripts/run_tests.ps1 -GodotPath 'C:/path/to/Godot_console.exe' -TestName @('block_test', 'area_streaming_test')
```

Names must match `tests/*_test.tscn` basenames. Logs go to `.godot/validation`. The runner requires exit code zero, a `PASS:` or `<scene>_test: PASS` marker, and no engine errors or warnings. A printed PASS does not override an earlier assertion or engine error.

For direct diagnosis:

```powershell
& 'C:/path/to/Godot_console.exe' --headless --path . res://tests/transition_test.tscn --max-fps 60 --quit-after 1800
```

Run tests for changed behavior and affected integrations. Omitting `-TestName` discovers every regression scene; use that only for an explicitly requested full-suite run. The full suite has not been requalified after the cleanup. `window_render_test` requires a display and explicitly skips headless execution; the current runner treats that skip as a failure because it requires PASS. Run rendered-only checks separately.

## Rendered checks

Run a scene without `--headless` to exercise its image assertions. The project defaults to D3D12 Forward+ on Windows. OpenGL Compatibility is an additional useful check:

```powershell
& 'C:/path/to/Godot_console.exe' --path . res://tests/shadow_style_test.tscn --max-fps 60 --quit-after 1800
& 'C:/path/to/Godot_console.exe' --path . res://tests/window_render_test.tscn --rendering-method gl_compatibility --rendering-driver opengl3 --max-fps 60 --quit-after 1800
```

`shadow_style_test` checks Game and standalone Soft/Crisp/Outer Blur/null composition, replacement, bypass, and restoration. Its image reads map logical pixel centers into the actual fitted image. `window_render_test` checks fitted dimensions and all styles at 768×720, 1024×960, and 1000×700. Both pass their focused rendered checks on OpenGL Compatibility and D3D12 Forward+.

`koopa_shadow_test` compares both walking poses at integer placements; headless execution skips its image checks. Fractional-position rasterization differences and the natural moving-Koopa pixel report remain open. Rendered checks and listening comparisons are required for visual/audio fidelity; headless playback assertions alone do not establish it.

## Fixtures and ownership boundaries

Configure single-stage fixtures through `game.stages.assign([scene])` and reload through `game.stages[0]`. There is no `initial_level` alias. Assign timer settings and `player_start_configuration` before adding a fixture to the tree. `level_timer_test` explicitly selects enabled/disabled timer behavior, and `mario_form_test` explicitly selects Super; neither assumes the sandbox's defaults.

Use typed GameHandler setters such as `set_score()`, `set_coins()`, and `set_lives()`, with reads through `player_status`. Generic session access is for area/arrival IDs and custom run metadata. `state_machine_test`, `level_completion_test`, and `transport_lifecycle_test` cover metadata retention/reset and synchronous observer replacement.

The four Mesen transformation datasets used by `growth_handoff_test` are committed as `tests/fixtures/transformation_reference/transformation-mesen-*.csv`. They cover growth/damage while running/jumping, with the same bytes as the original captures. The fixture subfolder has a `.gdignore` so Godot does not import raw captures as translation tables; FileAccess reads them directly. Tests must not depend on ignored local research folders.

| Boundary | Focused checks |
| --- | --- |
| Area content and progress | `block_test`, `level_progress_test`, `area_streaming_test`, `layout_grid_test`, `area_theme_test` |
| Spawn registry and policy | `enemy_spawn_test`, `one_up_test`, `super_mushroom_test`, `question_block_test`, `nested_entity_activity_test` |
| Entity theme application | `area_theme_test`, `mario_form_test`, `climbing_test`, `fireworks_test`, `animation_clock_test` |
| Entity activity and input | `entity_activity_test`, `nested_entity_activity_test`, `entity_input_test`, `enemy_contract_test` |
| UI theme binding | `area_theme_binding_test`, `hud_test`, `hud_scroll_test`, `title_test`, `player_status_test` |
| Lifecycle and presentation | `death_test`, `game_over_test`, `level_timer_test`, `transition_test`, `title_backdrop_test`, `mario_form_presentation_test` |
| Authored scene structure | `scene_hierarchy_test`, `entity_registry_test` |

BaseLevel owns area lifecycle and progress storage calls. `block_test` re-enters `_load_area(active_area)` and checks count plus original entity identity. `title_backdrop_test` injects markers through `level.area_content.populate_layout()`; ordinary runtime population stays behind BaseLevel's loaded-area guard. Slot assertions inspect `level.spawn_registry` while normal capacity/claim calls stay on BaseLevel.

Activity tests check both suspension orders, preservation of collision/state, processing restoration, and animation resynchronization. Nested tests verify that sleeping placements do not stop their live Goombas/shells, parent wake does not override child suspension, and cleanup releases spawn capacity. `AreaThemeBinding` checks cover idempotent startup, missing-theme fallback, instance-resource isolation, preserved HUD animation phase, old-area disconnection, and full subscription cleanup.

## Movement, contact, and rewards

- `jump_benchmark_test` checks six takeoff positions, launch displacement/speed, exact 83-pixel logical rise from the rounded takeoff baseline, and expected reach/miss outcomes.
- `landing_rejump_test` compares 20 Small/Super, both-direction flat-ground cases with recorded reference data: immediate/delayed re-jumps, tapped/held Jump, contact-frame rejection, initial velocity, early horizontal samples, apex tolerance, and one integration per tick. It does not establish all-terrain parity or input buffering.
- `down_direction_test` checks grounded Down/direction filtering and coasting, low-speed stop rules, crouch release, jump eligibility, and airborne steering. `super_mario_movement_test` retains crouch-jump/landing coverage.
- `canvas_terrain_test`, `super_mario_corner_test`, and `enemy_canvas_test` exercise head/side contact, block/ground response, real hurtbox overlaps, and block-hit shape queries across canvas hierarchies.
- `vertical_fraction_test` compares 313 captured arithmetic steps exactly. `vertical_jump_reference_test` checks a natural stationary jump/break sequence. `brick_seam_reference_test` compares 182 post-break vertical samples from 14 running/seam routes while replaying recorded horizontal positions; it does not independently verify horizontal integration.
- `brick_neighbor_test` checks 20 full-jump cases, reaction gating, and directional outcomes. `brick_break_test` / `brick_debris_test` cover capability selection, temporary collision, scoring, theme, pause, and effect cleanup.
- `block_top_coin_test` covers Small bumps and Super breaks across both canvas hierarchies. It checks same-cell pickup, adjacent coin exclusion, duplicate collection, rollover, effect origin and pause, and coin persistence after an area round trip.
- `enemy_boundary_test` covers activation-column rounding, cleanup thresholds, and simultaneous paired movement. `shell_spawn_contact_test` verifies retry after rejected contact, exactly-once chain rewards, and a moving shell passing the far Goomba of a pair beyond the right edge.
- `score_popup_test` checks placement, optional rise/cleanup, pause, display-only lifetime, and absence of reward side effects. Entity callers retain reward ownership; flagpole and block-coin lifetimes remain separate.
- `camera_arrival_test`, `corner_correction_test`, and `area_background_test` cover return-pipe framing, correction-excluded camera progress, background bounds, and shadow routing.

Pipe entry/transfer, sideways-pipe, climbing, and flagpole-ending tests also accept `-- --super` for their Super configuration. Their timing/contact assertions should remain meaningful when fixtures are isolated from authored stage settings.

`jump_benchmark_test`, `super_mushroom_test`, `pipe_transfer_test`, and `flagpole_ending_test` accept `-- --luigi` to use Luigi's inherited scene. Add `--trace` to the jump benchmark to compare per-tick position, velocity, and state.

`fire_form_test` checks Fire artwork for Overworld, Underground, and Castle, 63-update palette timing, pause, walking atlas alignment, cancellation, and character-specific Fire-to-Small damage. Run it with rendering enabled to capture each character during the palette cycle.

`fire_flower_test` checks block emergence and crop, four global palette phases, stationary motion, pickup for both characters in all three forms, and the delayed 1,000-point reward. A rendered run captures the flower partway through emergence.

`starman_test` checks release from painted reward data, all four item frames in each theme, emergence clipping, collection at four pixels of rise, the five-tick score delay, and bounce and wall-reversal positions from Mesen.

`starman_effect_test` checks two complete Mesen timing traces, enemy damage protection, the music handoff, refresh, and pause. Run it with a renderer to also check the recolored sprite pixels and Fire throw overlay.

`starman_enemy_test` checks contact priority, the hit-frame pose and body movement, the next-update reveal, and the five-tick score award. It includes a Koopa hit at exact box-edge contact before Godot refreshes its cached overlap. It covers walking and squashed Goombas, walking Koopas, and idle, moving, and stunned shells.

`fireball_test` compares per-tick positions, vertical speeds, and bounce flags with the Mesen right, left, and wall traces. It checks burst frame selection and release timing, fresh versus held Run input, alternating slot rejection and reuse, and player limits of zero, one, and two.

The same test checks Fire throw duration and pose selection for both characters while standing, walking, running, and jumping with or without horizontal movement. A rendered run checks each pixel of the full throw and the two partial compositions in both directions.

The enemy impact fixtures use captured Goomba, Koopa, and shell positions to compare contact timing, the initial knockout step, the early launch arc, delayed scoring, and burst release. They also check the left and right eligibility cutoffs and a shot that defeats two enemies in descending slot order.

`title_test` checks the HUD name and lives portrait on the initial and restart intro cards and the Mario reset on title return. The Time Up and Game Over tests check the active name on those cards, including Game Over after the player level is removed.

Pipe entry and transfer checks cover simultaneous Up+Down, grounded Down with a horizontal direction, and Down+Right on the landing tick. The sideways check walks to the lower mouth, releases Right, and verifies entry with neutral input when facing right and rejection when facing left.

## Deterministic audio teardown

Successful scenes call `await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())` after assertions and ordinary cleanup. This stops remaining non-positional audio and waits for two observed AudioServer mix boundaries, with a one-second timeout. A cooperative one-millisecond pacing step prevents accelerated frames from exhausting the test limit while the audio thread waits. Timeout fails the test; warnings are not suppressed. Only final test teardown pauses the test tree.

`audio_shutdown_test` verifies stopped stream/playback weak references become invalid. This addresses the isolated deferred-audio cleanup warnings; native shutdown failures still need investigation if reproducible.

## Manual play and listening

- Exercise keyboard/controller movement, quick reversals, landing/re-jumps, and pipe/ledge contact at different window sizes and refresh rates.
- Pause during jumps, item release, pipe animation, death, and endings. Verify frozen world/audio, the pause cue, and fresh-press resume; repeat in F6.
- Travel through 1-1's secret area and return. Check camera, artwork, HUD, music, and retained rewards.
- Test Super growth/shrink while running and airborne, crouch release inside terrain, damage protection, and subsequent collection.
- Verify question/hidden/reward-brick contents, coin rollover, depletion, ordinary brick debris and 50 points, then revisit the area.
- Verify life loss by enemy/pit/timeout, restart, and final-life return to a clean title.
- Finish with timer endings 1, 3, and 6; check fireworks, 500 points per burst, pause, score conversion, and music handoff.
- Compare audio with Mesen at the same playback level. Investigate note period, envelope, cutoff, retrigger, and channel interaction before changing pitch or amplitude.

`arrival_control_test` verifies exactly 17 locked movement ticks followed by held-input response, continued falling, controller disconnection/reconnection, pause preservation, direct-placement timing, a stationary 17-tick pre-emergence hold, immediate control after animated exit, cancellation, and unchanged start/respawn eligibility. Pipe entry/transfer, sideways travel, camera return, transport lifecycle, death, title, and pause scenes cover the affected integrations.

`title_background_test` verifies a Game-selected backdrop on startup and stage-completion return, suspended backdrop actors, an unchanged gameplay stage list, and a different backdrop selection on a later menu return. Default-backdrop, game-over, and animated-return paths remain covered by the title/lifecycle regressions.

The former playable Test Level is retained only as `tests/fixtures/sandbox_level.tscn`. Regression scenes use its stable geometry independently of 1-1 and the configured title backdrop.

`delayed_reward_test` checks the six-update enemy/power-up award delay, pause, exactly-once delivery after actor/popup deletion, concurrent life awards, and shutdown cancellation. Enemy interaction tests wait for pending awards separately from their immediate reaction assertions.

`spawn_registry_test` verifies category-local slot lookup before tree entry, the ten-enemy cap, lowest-free reuse without renumbering, independent power-up capacity, untracked categories, oldest-actor replacement, and safe release after deferred replacement exits.

`block_hit_receiver_test` verifies acknowledged enemy/mushroom delivery, repeated recoverable hits, permanent-defeat rejection, unbound/freed callbacks, emergence and suspension guards, and unchanged launch direction/velocity.

`block_receiver_order_test` checks 12 receiver arrangements for both bump and break on normal and CanvasLayer-backed levels (48 combinations): slot/tree ordering, slot reuse, category priority, rejected and out-of-range receivers, unregistered fallback, emerging power-ups, the tenth enemy slot, no accepted receiver, and exactly one delayed entity reward.
