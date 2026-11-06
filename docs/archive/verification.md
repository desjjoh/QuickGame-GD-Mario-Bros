# Verification

Run the complete regression set from the project root, passing the console Godot executable:

```powershell
./scripts/run_tests.ps1 -GodotPath 'C:\path\to\Godot_console.exe'
```

The runner discovers tests/*_test.tscn, uses the normal project/autoload startup at a 60 FPS cap, and bounds each run with --quit-after 1800. A zero exit code alone is insufficient: each scene must print PASS, with no SCRIPT ERROR, ERROR, or WARNING lines. A failed scene makes the command fail. Logs are written under .godot/validation. APPDATA/LOCALAPPDATA overrides are restored afterward.

The current 38 scenes cover:

| Area | Coverage |
| --- | --- |
| Death | Pit visibility threshold, suspension/animation, player cleanup, optional presentation, death audio, global preserve/reset across areas, spawn restart, unchanged lives and stale completion |
| HUD | 8px glyph metrics/grid, static values, input pass-through, coin cadence and persistence across camera/area/level changes and transition content |
| HUD scrolling | Fixed screen-space structure; rendered foreground glyph comparison through changing physics-camera speed at multiple render rates (rendered checks skipped headlessly) |
| Shared shadow | Rendered foreground occlusion, HUD-cast shadow, fractional camera stability, logical player ownership, pipe draw mode and replacement |
| Shared animation clock | Exact 48-tick phases/wrap, late/themed joins, death suspension, bounce/used ownership, cleanup and continuity across area/level/session changes |
| Run release | Tick-ten directional walk clamp, both directions, re-press, neutral braking, skid/air ownership, level cap precedence and once-only state handoff timing |
| States/lifecycle | Ownership, presentation hooks, callback gates, shutdown once, replacement, nested entities, input disconnection |
| Movement handoffs | 44 combinations across Idle/Move/Slide/Jump, exactly one body integration, first-tick acceleration, falling gravity, matching camera displacement and shutdown during transition |
| Scene hierarchy | Three native editor-state save/reload cycles preserve nested endpoint parents and all painted layouts |
| Transport lifecycle | Duplicate queued completion cannot skip emergence; shutdown cleans up; synchronous level replacement cannot publish stale session IDs or restart the old player |
| Movement | Walk/run, shared modifiers, reversal, slide retention, air rates and context, immediate exactly-once takeoff movement from Idle/Move/Slide |
| Jump/collision | Variable height, weight, ceilings/audio, gap clearance, ledges, bounded corner correction, running-gap recovery, two-tile gaps onto lower pipe tops at eleven subpixel phases in both directions |
| Animation | Walk cadence, static poses, passive-fall freezing/resume, question-block phases, one-shot Bonk activation, used appearance and fixed-collider bounce |
| Input | Keyboard and raw controller primary events, gating |
| Pipe entry | Control lock, reference-speed descent, source-camera freeze, once-only audio, target invalidation, and shutdown restoration |
| Sideways pipe | Real-input side entry, horizontal travel, area unloading, walking sprite cycling, aligned concealed wait, 96-tick upward emergence, no intermediate Idle, exact control handoff, discarded locked jump input, entry-only sound and compatible theme sources |
| Spawn return | Actual secret return follows moved PlayerSpawn while MainArea is unloaded; restores camera/control with no exit pipe or emergence |
| Transport | Explicit/moved entity targets, non-pipe presentation, saved per-cell resources, exit-only permissions, stale/duplicate/missing/removed rejection and session preservation |
| Pipe routing | Per-cell route save/reload, named/default endpoints, same-area travel, direction metadata, invalid/stale targets, camera repositioning, and reentry lock |
| Pipe travel | Vertical descent preserves off-center position and both facing directions; Painted entrance, ground/alignment/control gates, deferred transfer, cameras, movement reset, session preservation, and shutdown |
| Area lifecycle (area_music_test) | Entry/exit ownership, preload stays inactive, cross-area handoff, absence of soundtrack players and shutdown |
| Area streaming | Actual node/collision removal, repeated visits, progress restoration, removed entities, tile edits, level replacement, and foreground cleanup |
| Area themes | Independent TileSets, all 20 Underground texture mappings, terrain collisions, both pipes, question animation/used art, themed previews, decoration fallback, resource isolation, inherited bounce, and shutdown |
| Lower area | Main camera remains current at startup; simulated arrival uses fixed lower camera and enclosed terrain, with player containment in both directions |
| Pipe/wall camera | Repeated blocked short hops from both sides at walk/run speeds cannot ratchet scrolling; clearing the pipe resumes rightward tracking |
| Camera | Edge clamping, scroll thresholds, constant fractional steps, one-way limits, live traversal |
| Layout grid | Inherited ground layer, reset transforms and cell size/shape, preserved painted cells, matching cell origins and entity placement |
| Bonk contacts | Partial underside hits at both edges, correct target left/at/right of a seam, no redirection from a used block, no activation on side-only contacts or escaped corners |
| Level entities | Marker generation, no duplicate spawning, non-solid entities, solid blocks, repeatable brick bounces, hit rejection during bounce, coordinates, shutdown |

The wider camera and block tests construct their own fixtures; changing the painted test stage should not redefine those expectations.

For scene cleanup, also check scene/resource paths and declared-resource usage, instantiate the generic bases and concrete scenes, and inspect a rendered preview. Empty state machines are deliberately supported. Mario-only Presentation belongs to Mario; BasePlayer supplies its referenced AnimationPlayer and shared physics/actions.

Headless tests do not prove subjective movement feel, display frame pacing, speaker output, or renderer performance. A Forward+ render smoke check can catch scene/material failures and layering regressions, but interactive editor playtesting remains useful. No exact NES trace qualification is claimed.

Integration tests retain `tests/fixtures/silent_game.tscn` and `silent_level.tscn` as shared inherited fixtures, now without music overrides. area_music_test retains its existing entry point but checks silent area lifecycle behavior; it no longer decodes soundtrack assets. Music playback and audible-loop qualification are deferred in the [backlog](../backlog.md).

## Global transition milestone - 2026-11-03

All 39 regression scenes passed without engine errors or warnings. transition_test additionally passed under Forward+ D3D12 with rendered black-cover pixel assertions and quick/card captures. It exercises enabled startup, real pipe travel, death restart, slow loading, minimum holds, controller/entity restoration, overlap rejection and cancellation/stale transactions. Timing-focused existing fixtures disable transitions explicitly. These checks do not establish subjective transition pacing or exact NES frame traces.

ledge_camera_test adds 72 Jump-state corner landings across block/pipe-width geometry, both directions, two speeds and multiple contact phases/depths; a rendered run at a 240 FPS cap checks horizontal displacement and camera advance. hud_test checks Underground atlas mapping, Overworld fallback/reload, resource isolation and retained global animation phase. Monitor frame pacing remains unconfirmed.

## Deterministic bonk sweeps and process exits

bonk_contact_test executes its character sweeps in a physics callback and asserts Engine.is_in_physics_frame(). Calling move_and_slide from a render-frame continuation made its integration delta depend on render cadence; the original fixture reproduced its X=72 failure at a 240 FPS cap. Fixed sweeps passed eight headless stress runs across 45/60/144/240 FPS caps and a rendered Forward+ run at 240. Gameplay collision rules were not changed.

The runner reports engine exit codes and continues rejecting nonzero exits even when assertions print PASS. A separate native access violation (Windows 0xC0000005) reproduced once in thirty launches of an empty scene with the project autoloads. Loading TransitionCoordinator at runtime instead of statically constructing it in GameHandler removes that static script dependency cycle; the same probe then passed one hundred launches. No automatic retry, crash-code exemption or arbitrary shutdown wait was added. This is bounded local evidence, not a guarantee against every native engine failure.

Final verification for this milestone: the complete forty-scene suite passed with zero engine errors, warnings and nonzero exits after the dependency/sweep corrections. The transition wait helper subsequently switched its timeout from render frames to physics ticks; focused headless and Forward+ D3D12 runs at a 240 FPS cap passed. This avoids an artificial 0.75-second timeout on a 0.8-second pipe entry. Documentation UTF-8/file links and whitespace checks passed. CI has not been run or inspected for this commit. The reported intermittent monitor hitch remains open.

## SFX mix milestone

sound_mix_test checks actual gains on entity and death players, cloned source identity, preserved one-shot duration/loops/pitch, cancellation and repeat gains. Headless and rendered 240 FPS-cap checks passed. Full-suite outcome: 40 of 41 scenes passed; scene_hierarchy_test had passing assertions followed by a native access violation. The unchanged focused rerun passed. The full run remains failed and native shutdown is backlogged; prior clean-run evidence is historical, not proof this issue is eliminated. Gain application is measured; final perceptual balancing still requires listening on the user's speakers/headphones. See [audio](audio.md).

## Extensible transition definitions

Expanded transition_test passed headless and rendered at a 240 FPS cap with exit zero: no Cover node, black pixel checks, arbitrary registered presentation scenes, Resource isolation/snapshots, HUD/background/timings, generic replacement permission, invalid IDs/roots, cancellation during presentation initialization and clear-color restoration. Existing pipe/startup/respawn/cancellation behavior remains covered. Full 41-scene run: forty passes, plus scene_hierarchy_test with passing assertions followed by native access violation -1073741819. This full run is failed; shutdown investigation remains open.

Transition background correction: rendered transition_test passed at a 240 FPS cap with a deliberately nonblack clear color. It verifies the background remains unchanged throughout presentation/cancellation, and no Cover node exists. Transition production code makes no clear-color changes. This supersedes earlier black-frame/temporary-color assertions; prior full-suite native shutdown results remain recorded above.

Stage split verification: 1-1 retained the original scene UID and all serialized data apart from its root name; Game/fixtures now load 1-1. The new unconnected TestLevel has a distinct UID, one 256x240 area, 32 ground cells and empty decoration/entity/transport data; native save/reload and rendered standalone spawn passed. Full 41-scene run: forty passes, plus area_theme_test with passing assertions followed by native access violation -1073741819. The existing shutdown backlog item remains open.

## Title flow milestone

title_test exercises the normal enabled title startup, frozen background Mario and level callback, white HUD font and 8x8 cursor, approved Start bindings/raw controller events, exactly one level transition, new session initialization, Enter consumption, fresh gameplay Jump, cancellation and Game detach. Headless 60/240 FPS and rendered 240 FPS checks passed; after the full-run playback-resource warning, its final focused test waits for the verified Jump one-shot to finish before teardown and exits warning-free. Full 42-scene run: thirty-nine clean passes, two post-PASS native access violations (controller_primary_test/death_test), and the title cleanup warning subsequently corrected in focused runs. The full run remains failed. Tests simulate input events; physical controller/display playtesting remains separate.

## Entity controller opt-in

entity_input_test passed headlessly and rendered at a 240 FPS cap, checking default opt-out, explicit player/pipe capability, actual signal connections/delivery, duplicate prevention, live toggles, reversible suspension, polling gates and dead/shutdown cleanup. The movement-handoff probe now preserves the player scene's controller flag when swapping scripts; all 44 cases pass. Final full 43-scene run: forty-two clean passes, plus area_streaming_test with passing assertions followed by native access violation -1073741819. The full run remains failed. Callback scheduling/off-camera behavior and memory benchmarks are outside this milestone.

## BaseArea camera activity and enemy spawner foundation

Final full regression run: all 44 test scenes passed with exit code zero and no engine errors or warnings. The earlier full run also passed all 44; the final run follows the authored-template, native sprite animation and spawner-origin corrections. entity_activity_test additionally passed headlessly at 60 FPS and rendered with a 240 FPS cap. It checks zero offscreen frame/physics ticks, input suspension, retained instance/state and live collision, separate suspension gates, shared animation phase on wake, hysteresis, moving-child enemy bounds, disposal/reentry, authored-template reload, area unload cleanup and blocked spawning during title/death/transition freezes. Documentation local file links and patch whitespace checks passed. No large-stage CPU/memory benchmark or physical 240 Hz display validation was performed. The historical intermittent native shutdown issue remains in the backlog; clean runs do not establish its resolution.

## Shared player status and live UI - 2026-11-04

Full local regression run: all 45 test scenes passed with exit zero and no engine errors or warnings. New player_status_test passed headlessly at 60 FPS and with rendering enabled at a 240 FPS cap. It covers defaults/bounds, change-only notifications, legacy session-key routing, initial/live HUD/title/intro values, new-game reset with retained top score, area/death continuity and absence of automatic rewards. Updated hud_test verifies score updates instead of the superseded static-value behavior. Rendered .godot/validation/player-status-title.png was inspected: top score is white bitmap text on the 8x8 grid, beneath the existing menu, sharing the composed shadow. Documentation local file links and patch whitespace checks passed. No CI run, physical controller/display validation or disk-save test was performed; disk persistence is not implemented. The historical intermittent engine-shutdown issue remains tracked independently.

## Palette asset folder migration - 2026-11-04

All 45 local regression scenes passed with exit zero and no engine errors/warnings after migrating to assets/palettes/overworld and assets/palettes/underground. Rendered title_test also passed at a 240 FPS cap, covering alternate font, theme override/fallback and menu lifecycle. Verified 58 source-file hashes against a pre-move manifest, preserving current artwork including user edits, plus 58 existing import UIDs/parameter records and all expected generated cache files. The font importer automatically skipped the atlas texture; its original configuration was restored and the missing relocated texture cache was regenerated in a clean import pass. Explicit runtime resource paths, absence of legacy palette names in current resources/guides, current documentation links and patch whitespace checks passed. Historical guides retain old path descriptions intentionally. No export build or CI run was performed.

Underground title accent font: rendered title_test passed at a 240 FPS cap after assigning the supplied Underground alphabet through its bitmap-font wrapper. Coverage checks initial themed creation, live Overworld/Underground switching, missing-theme fallback and preservation of white menu text. The cyan copyright screenshot was inspected. Existing PNG import settings were restored after the font importer and verified unchanged.

Palette-aware title card: rendered title_test passed at a 240 FPS cap with both theme selections, native 192x96 dimensions at (32,32), fallback, newly created Underground instances and source-scene isolation. The Underground screenshot was inspected for HUD/copyright/menu placement and shared shadow. area_theme_test passed after updating its expected texture inventory from 20 to 21 for the new card. Both PNGs were exported with the installed Aseprite batch exporter; editable originals are retained. The full suite was not rerun for this artwork-only UI extension.

Underground decorations: area_theme_test passed with all 15 matching decoration source IDs, atlas/alternative IDs, 16x16 grid, no physics layers, equal texture dimensions and Overworld resource isolation. Rendered title_test passed at a 240 FPS cap; the Underground background screenshot was inspected with its new themed hills/clouds/bushes. No painted cells were changed, and the pre-existing test_level scene edits were preserved. Full-suite/CI/export checks were not rerun for this asset-only theme extension.

## GDScript cleanup and lifecycle review - 2026-11-04

Final full local run: all 45 regression scenes passed with zero exit codes and no engine errors/warnings. Focused HUD and title tests also passed with rendering enabled at a 240 FPS cap. The initial full run failed the title's obsolete empty-background assertion and Godot parsing of two formatter-expanded lambdas; title suspension/assertions were corrected and the callbacks extracted to an equivalent named helper before the final full run. A shorter rendered title attempt reached its frame limit without PASS; only the completed follow-up with a sufficient frame allowance is counted as verification.

Formatting check passes for all 111 GDScript files; 94 changed. Syntax-tree/comment-preservation/stability comparisons against the pre-cleanup snapshot passed for 106 formatting-only scripts. HUD/GameHandler and their tests contain the targeted theme/title suspension fixes; transition_test also contains the callback-helper extraction. The HUD regression first reproduced the missing theme signal with the manual-refresh workaround removed, then passed automatic refresh and old-area disconnection assertions after the fix.

Strict default gdtoolkit lint remains failed with 135 findings, down from 416: 76 declaration-order, 40 line-length, 15 repeated-load, three return-count and one public-method-count findings. No lint rules were suppressed. Current documentation links and patch whitespace checks passed. No Project Settings/Input Map/import parameters or user-painted scene/artwork data were changed by the cleanup. Existing standalone F6 death restart and intermittent native-shutdown backlog items remain open. CI, export builds and physical controller/display testing were not performed.

World folder organization: scene_hierarchy_test, title_test and death_test passed after moving the unchanged stage to scenes/levels/worlds/world 1/1-1.tscn. Confirmed the scene bytes/UID were preserved, no old runtime/test resource paths remain, native save/reload still preserves paint and hierarchy, title Start loads the relocated stage and death restart reloads it. The full regression suite was not rerun for this path-only change.

## Accepted death reduces lives - 2026-11-04

All 45 local regression scenes passed with exit zero and no engine errors/warnings. Expanded death_test verifies one deduction at accepted death, no extra charge from duplicate/reentrant calls or restart, rejection of another player's death request, live intro lives text, preservation of the reduced value with either world-progress policy, zero clamping with current respawn behavior, and synchronous level replacement from a lives-change observer without stale death audio/cleanup. Existing status and transition tests also pass. Changed-script formatting, guide file links and patch whitespace checks passed. No game-over behavior, physical input/display testing, CI or export build was added/run.

## Game over, reserve lives and one-level progress - 2026-11-04

Full local regression run: all 47 scenes passed with exit zero and no engine errors/warnings. game_over_test and level_progress_test were added; status/death tests now use stored reserves=2/displayed lives=3 and negative-only termination. After the full run, game_over_test gained an additional stalled-presentation timeout scenario and passed with rendering enabled at a 240 FPS cap. No runtime code changed after the full run. The rendered game-over screenshot was inspected: white GAME OVER text, visible HUD, hidden gameplay and the unchanged existing viewport background.

Coverage includes three total attempts, zero still playable, -1 selecting game over after death completion, the 378-frame card minimum, actual one-shot audio completion when the minimum is shortened, missing audio, bounded stalled completion, explicit shutdown-before-clear, same-level/area progress retention, different-level reset, copied snapshot data, stale writes from a previous visit, held Start release, new-game defaults/top-score retention, external level replacement and Game detach during the card. Generic transition cancellation now releases an obsolete transition flag on an externally initialized replacement. Test fixtures shorten selected runtime definitions without changing authored resources.

Formatter check passes for all 115 GDScript files. Current guide file links and patch whitespace checks passed. Supplied game-over audio uses -5 dB stream trim plus -3 dB master; speaker/headphone balance was not manually auditioned. Start-to-skip, continues, two-player flow, collectible coin entities, top-score promotion/disk saving and standalone F6 death recovery remain outside this milestone. CI, export builds and physical controller/display testing were not performed. The historical native engine shutdown issue remains tracked independently; these runs did not reproduce it.


## Two-pass shared shadow - 2026-11-04

Rendered shared_shadow_test passed at a 240 FPS cap: nonzero-radius blur agrees with a CPU evaluation of the original 13x13 Gaussian within 0.02 color tolerance; sharp foreground occlusion, moving/color-changing same-frame output, camera fractions, padded buffer size, disabled updates/startup, restoration and level replacement pass. Rendered hud_scroll_test, hud_test, sideways_pipe_test and title_test passed with no engine errors/warnings. Gameplay and blur screenshots were inspected.

Full local regression run: 46 clean scenes; game_over_test printed PASS and exited zero but emitted a two-object leak warning, so the full suite is failed. Verbose output identified AudioStreamWAV and AudioStreamPlaybackWAV. The same warning reproduced with the committed pre-blur Game scene/compositor restored temporarily for the comparison; the new renderer was then restored. This is an audio teardown issue, not established as a rendering regression. An attempted explicit stream release did not resolve it and was reverted. No assertion or warning checks were weakened.

Controlled automatic running/jumping captures, RTX 3070 Ti, Forward+ D3D12, 240 FPS cap, five seconds/1,200 sampled frames per mode after warm-up: a serial repeat with no regression suite running measured legacy median GPU 0.064ms (p99 0.069), CPU rendering 0.048ms; two-pass median GPU 0.032ms (p99 0.034), CPU rendering 0.080ms. CPU values include viewport rendering plus frame setup; GPU values sum active viewports. Median frame interval was 4.167ms for both; p99 was 4.403ms legacy and 4.286ms two-pass. Canvas compilation counters stayed flat at 2 legacy and 3 two-pass during sampling. Neither reproduced the reported hitch. An earlier three-mode capture measured off at median GPU 0.009ms, but overlapped the headless suite and is only a secondary reference. Diagnostic scene teardown was subsequently made explicit; the serial repeats exited cleanly. Raw CSV files remain under ignored .godot/validation user data.

These short capped local measurements show lower GPU work with higher CPU rendering overhead, not a proven end-to-end speedup or physical-display fix. No export, CI or user-monitor validation was performed. The standalone/editor level shader is unchanged. Project Settings and imports are unchanged.


## Edge skids and title-owned progress cleanup - 2026-11-04

Final full local regression run: all 48 scenes passed with exit zero and no engine errors/warnings. New slide_collision_test passed rendered at a 240 FPS cap and headlessly in the full run; its final version also asserts the actual skid sprite on collision. camera_bounds_test covers both edges/zooms, inward/outward/neutral input and vertical-speed preservation; wall-hop and eleven-phase lower-pipe landing checks passed. The 44-case movement-handoff test and existing skid-release regressions passed. New collision sweeps run in real physics callbacks after fixture collision registration.

Rendered game_over_test passed, verifying that the final progress snapshot remains during the card and is gone after common title entry, plus stale completion protection and final-detach snapshot retention. level_progress_test also verifies a playable TestLevel-to-title return clears progress even though the logical scene path is unchanged. The initial full run caught an unintended generic detach clear that broke area_streaming_test's existing cross-Game snapshot contract; that change was removed, its focused rerun passed, and the final full run above passed. No test expectation for ordinary detach persistence was weakened.

Changed-script formatting, current guide links and patch whitespace checks passed. No physics/renderer/Project Settings or binding changes were introduced by this milestone. Physical-controller playtesting and CI were not run. The earlier audio/native shutdown warnings remain historical backlog items; this clean run does not establish their permanent resolution.


## Held Run investigation - 2026-11-04

Rendered held_run_landing_test passed at a 240 FPS cap: 16 complete jump/landing cycles over keyboard/simulated-controller events and both directions, continuously held Run without a re-press, live mapped/handler input, removed air modifiers and restored ground speed/cap. The opt-in run_input_probe rendered startup/shutdown smoke check exited zero, saved CSV output and produced no engine errors/warnings. No production gameplay/input/settings changes were made; the reported physical-controller occurrence is still unconfirmed and requires capture. The complete suite was not rerun for these diagnostic-only additions.


## Ordered stages and completion lifecycle - 2026-11-04

Full local run: 49 clean scenes; game_over_test printed PASS and exited zero but emitted the existing two-object audio teardown leak warning, so the 50-scene run is failed. No warning/exit checks were weakened. The first attempted full run was interrupted after a typed-array compatibility setter error; the setter was corrected to create an explicit Array[PackedScene], and the subsequent full run above passed its affected fixture assertions. The audio warning is tracked separately in the backlog and was previously reproduced before completion work.

level_completion_test passed headlessly and rendered at a 240 FPS cap. Its final rendered follow-up also covers rejected-transition recovery and includes the final dead/removed-player guard. Coverage includes direct/animated stage advancement; duplicate/death/transport rejection; preserved score, coins, reserves and power-up form; next-stage label/time initialization; old-progress disposal; repeated same-scene list entries; final-stage title return/frozen background; Warp requiring a destination and using the level intro; unlisted override behavior; cancellation; new-game restart; and synchronous source replacement. Rendered title_test passed with its existing default/alternate launch and cancellation coverage. No physical ending trigger, timer countdown, completion fanfare or player-form artwork was added.

Changed-script formatting, current local documentation links and patch whitespace checks passed. No Project Settings, Input Map or import settings were deliberately changed. Export/CI and physical-device validation were not run for this milestone.


## Full run cleanup on title return - 2026-11-04

Rendered level_completion_test, title_test, game_over_test and player_status_test passed at a 240 FPS cap with exit zero and no engine errors/warnings. Return-path assertions check default score/coins, Small form, two reserves, cleared custom session/progress/pending destination, reset stage index and retained top score. Inter-stage status carry and explicit alternate-stage startup remain covered. Formatting and patch whitespace checks passed. The full suite was not rerun for this targeted reset change; historical full-run audio cleanup warnings remain tracked separately.


## Mario Dead state - 2026-11-04

Final full local regression run: all 51 scenes passed with exit zero and no engine errors/warnings. New dead_state_test also passed rendered at a 240 FPS cap, including both main/lower camera spaces, exact 16-tick hold, first -4px movement step, nominal launch/gravity/cap, fixed horizontal position and facing, static death sprite, blocked controls/collision, non-player suspension, whole-sprite offscreen completion, once-only life/presentation cleanup, deferred respawn and visible final-attempt game-over/title reset. The existing non-presented pit path remains immediate. Main/lower death screenshots were inspected.

The existing death_test initially failed its old post-game-over lives=-1 assertion; title entry now intentionally resets lives to two reserves under the previously approved full run reset. Updated that post-title expectation while retaining its immediate negative-reserve check. Rendered game_over_test passed independently. Changed-script formatting, current guide links and patch whitespace checks passed. No gameplay caller, trigger or input binding was added. CI/export/hardware playtesting were not run, and the continuous death trajectory is not fixed-point/cycle-accurate qualification. Historical audio/native-shutdown warnings remain tracked independently; this clean run does not establish their permanent resolution.

## Level timer and TIME UP - 2026-11-04

All 52 local regression scenes passed via scripts/run_tests.ps1 with exit zero and no engine errors/warnings. level_timer_test also passed rendered at a 240 FPS cap. It covers single load-time initialization, post-intro/idempotent start, full first 24-tick interval, phase-preserving pauses and area travel, unchanged shared animation-clock progression, disabled TestLevel digits with TIME retained, a full zero interval, timeout Small status/animated death, 147-frame TIME UP, and both lives-respawn and final-attempt game-over/title paths.

The new test initially checked a second area transfer before the deferred first transfer had started; it now waits for deferred travel and coordinator completion. Changed-script formatting and local documentation file links passed. git diff --check passed (Git emitted existing CRLF normalization notices). No Project Settings, bindings or import semantics changed. CI/export, physical-controller playtesting and original-hardware frame timing were not run. Historical intermittent audio/native cleanup warnings remain separately tracked.

## Fixed flagpole and reusable climbing - 2026-11-04

climbing_test passed headlessly and rendered at a 240 FPS cap; inspected the captured gameplay preview for sprite/pole alignment and full assembly/base. The final headless follow-up also verifies callback settings survive activity sleep/wake, and covers presented-death cleanup. Coverage includes painted marker spawning, solid base support, no surface controller subscription or polling, accepted attachment signals, stationary hang, exact nominal up/down travel, two-frame animation, Run/Jump restriction, side-switch delay, bounds, blocked immediate regrab, removal and area transport cleanup. The marker-generation helper ran without engine errors/warnings after switching it to imported texture resources.

Full 53-scene run: 51 clean checks, game_over_test printed PASS but emitted the previously tracked two-object audio teardown warning, and level_timer_test failed because TestLevel's saved timer_enabled=false override was missing. Restored that previously approved TestLevel setting. Focused final climbing, timer and game-over runs all printed PASS and exited zero without engine errors/warnings; game-over warning did not recur. The original full run remains recorded as failed rather than relabeled clean. No test warning gates were relaxed.

Seven changed/new scripts passed formatter checks. Local documentation file links and git diff --check passed (existing Git CRLF normalization notices remain). New art imports were registered; no Project Settings, input bindings or existing import semantics changed. Authored level painting was preserved. CI/export, physical-controller playtesting and fixed-point/cycle-accurate parity were not tested.

## Flagpole bottom attachment - 2026-11-04

Updated climbing_test passed rendered at a 240 FPS cap, exit zero without engine errors/warnings. It now asserts retained Climb/attachment at the bottom, no detach signal, stopped animation, resumed upward climbing within the solid-body collision margin, and explicit state-change release before the existing base support/removal/transport/death checks. Existing in-shaft nominal speed assertions remain exact; only the new movement-from-solid-contact assertion permits the body margin. Formatter checks passed. The full suite was not rerun for this localized bound change. Reference source inspection covered FlagpoleSlide, FlagpoleRoutine, HandleClimbing, VineCollision and Vine_AutoClimb; upper-limit behavior was investigated/documented, not changed.

## Climbing side input and flicker checks - 2026-11-04

Final climbing_test passed rendered at a 240 FPS cap and headlessly with exit zero and no engine errors/warnings. During side-switch trials, assertions monitor every physics/render callback and state_changed notification: Mario remains in Climb with a climbing texture at middle/top/base. Tests cover pose preservation, holding a switch without ejection, opposite-input cooldown, outward release from both sides, changed-input latch reset, same-tick release displacement, retained base attachment and existing transport/death cleanup. movement_handoff_test also passed all 44 handoffs.

The reported original one-frame FSM departure was not independently reproduced. The fix removes repeated first-pose seeks during neutral/horizontal input and resets interpolation on discrete side placement; the final regression prevents unnoticed state/texture departures in the covered cases. Intermediate diagnostic runs included a corrected collision-query experiment and a failed cooldown check; final code retains the original solid-wall query, and temporary traces were removed. Changed scripts passed formatter checks. Full-suite, physical-controller and interactive user confirmation were not run for this localized change.

## Shaft capture, no manual ejection and initial idle pose - 2026-11-04

Final full local run: all 54 regression scenes passed, exit zero with no engine errors/warnings. Both climbing_test and climb_capture_test also passed rendered at a 240 FPS cap. The capture fixture verifies 20 real movement ticks across the shaft at walk/run speed, from both sides at upper/middle/base and landing-edge heights; immediate capture while standing on the solid block; actual swept crossings with both endpoints outside the band; solid-wall occlusion and below-shaft rejection. Existing climbing coverage now requires both horizontal directions to retain attachment and verifies returning from the second animated pose to the first pose when movement stops.

The extreme-crossing test exposed a release-suppression edge case when overlap signals never saw a brief contact. Suppression now clears using actual body separation, and the final regression passes. Body-envelope contact plus before/after integration checks replace the old pre-movement feet-only gate; no claim of byte-for-byte NES collision fidelity is made. Six changed scripts passed formatting checks; local documentation links and git diff --check passed. No authored painting, Project Settings or bindings changed. CI/export and physical-controller playtesting were not run. Historical intermittent audio/native teardown issues remain separately tracked despite this clean run.

## Castle decoration atlas - 2026-11-05

Resource validation passed for both palettes: source 15 has seven 16x16 cells in a 64x32 texture, excludes (0,0), and adds no physics layers. area_theme_test initially failed its old 15-source count; updated it to 16 and checked matching atlas coordinates/alternatives instead of assuming every source contains (0,0). The final headless theme regression passed, exit zero without engine errors/warnings. Its formatter check passed. Castle textures were visually inspected. Full-suite, rendered scene painting and export were not run for this resource-only addition. Ending reference inspection is documented as a proposal, not implemented or playtested behavior.

## Flagpole ending presentation and title transition - 2026-11-05

Full local suite: 54 clean scenes; game_over_test printed PASS and exited zero but emitted the previously tracked two-object audio teardown leak warning, so the strict 55-scene run remains failed. Independent verbose retry again printed PASS and identified AudioStreamWAV/AudioStreamPlaybackWAV leaks; no warning gates were relaxed and this historical issue is not claimed resolved. No other full-run check failed.

flagpole_ending_test passed headlessly and rendered at a 240 FPS cap. Final rendered follow-up also covers flag reset/retry, integer/fractional flag motion with the reference threshold ordering/final overshoot, and recorded grab/time context. Coverage checks reference-derived stop/dismount positions and 24-tick hold; a real castle walk; locked camera and no catch-up on unlock; ignored player controls/stopped countdown; one-shot flag SFX; endpoint shutdown/removal and cleared references; score/fireworks gates that can independently delay/ignore stale tickets; actual stage-clear music after player retirement; minimum final wait; concealed title UI/background swap; common title cleanup/top-score preservation; cancellation/retry, external level replacement and source loss. Captured rendered descent/dismount/walk/retirement/title frames were inspected after compositor latency.

Focused final entity_activity_test passed after adding completion to the enemy-spawn suppression gate. Existing level_completion_test passed separately and in the full run, retaining direct/Warp progression and stale-observer behavior. New endpoint/gate test fixtures initially exposed inherited child-override packing issues; the authored endpoint is now a separate level-owned marker and test callback overrides are packed as editable instances. Those fixture failures were corrected before the final checks above.

Thirteen changed/new scripts passed formatter checks. Current local documentation file links and git diff --check passed. Supplied WAVs were imported with defaults and played through runtime non-looping copies; no existing import semantics, Project Settings, bindings or authored terrain/decoration painting changed. Authored 1-1 now references the presentation and independent doorway endpoint. CI/export and physical-controller playtesting were not run. Score/time conversion, castle-star-flag/firework visuals and castle-specific ending choreography remain intentionally unimplemented behind the new hooks; byte/cycle-accurate original-hardware parity is not claimed.

## Silent skid and visible final hold - 2026-11-05

Final slide_test, slide_collision_test and sound_mix_test passed headlessly, exit zero without engine errors/warnings. The slide regression now asserts that entering Slide creates no sound player while retaining its existing movement/pose checks. Removed obsolete skid-sound fixture setup and repeated-skid mix assertions with the runtime feature. The first slide assertion edit had an indentation error; it was corrected before the final passing run.

flagpole_ending_test printed PASS headlessly but emitted the tracked two-object audio cleanup warning, so that run is not clean. The final rendered 240-FPS run passed with exit zero and no engine errors/warnings. Its real-music case requires the final delay counter to remain zero during playback, then verifies a full 126-tick hold before the transition; delayed score/fireworks, cancellation and title concealment checks remain intact.

Reference inspection confirmed DrawFlagSetTimer loads six interval ticks, the divider reloads $14 (21-frame cadence), and DelayToAreaEnd concurrently checks event music. The new sequential post-music hold is explicitly documented as a requested visible-pause adaptation while reward/firework hooks are no-ops. Six changed scripts passed formatter checks; local documentation links and git diff --check passed. No active skid playback/mix references remain; the unused MP3/import were retained. Full-suite, CI/export and physical-controller playtesting were not run for this localized change.

## Ending audio gain trims - 2026-11-05

sound_mix_test passed headlessly, exit zero without engine errors/warnings. It now checks original/nested-copy gains for flagpole and stage-clear streams and actual FlagpoleEndingPresentation non-positional player gains (-5/-6 dB including master), retaining non-looping runtime copies. PCM peak/active-RMS measurements informed the trims; this is not perceptual-LUFS or hardware speaker qualification. Formatter and patch whitespace checks passed. Full-suite/export and subjective device audition were not run for the Resource-only production change.

## Upper flagpole grab correction - 2026-11-05

climb_capture_test passed headlessly and rendered at a 240 FPS cap: 28 real-tick captures now include feet Y=40/47.5 at the ball, an exact highest-position grab retained at Y=40, above-ball rejection, and a real full-speed jump from a raised step grabbing above the old Y=56 clamp. Base standing/landing edges, swept crossings and wall occlusion checks remain. The reset helper now lets normal player processing observe separation after a same-tick test grab.

flagpole_ending_test passed rendered at 240 FPS with its real-music scenario starting from feet Y=40; it verifies the ending records grab_height=152 and does not pull Mario down on state handoff. Ordinary climbing passed headlessly and in its final rendered run, including side switching and the new top bound. An initial rendered climbing run failed a synthetic direction assertion; the regression window is now unfocusable to avoid focus disruption, and all assertions remain intact. Final targeted runs exited zero without engine errors/warnings. Six changed scripts passed formatting, and local documentation links/patch whitespace checks passed. Full suite, CI/export and physical-controller playtesting were not run. Player sprite/collider/jump physics and authored stage layout were unchanged.

## Flag foreground regression and jump experiment rollback - 2026-11-05

A rendered flag-contact overlap regression reproduced foreground loss with the old compositor (0/139 opaque Mario pixels visible; pipe routing false), then passed with per-sync draw-index restoration (139/139). Its final isolated run disables unrelated audio and exits without engine errors/warnings. Rendered shared_shadow_test, flagpole_ending_test and climb_capture_test also passed without engine errors/warnings, covering HUD/world order, pipe routing, ending presentation and swept capture. No artwork was changed.

The position-before-gravity experiment was reverted at the user's request after playtesting. Jump-related production files, jump_test and movement_probe match their previous implementation. Post-revert jump_test and movement_handoff_test passed cleanly, including ceiling response, landing and 44 single-integration handoffs. A prior experimental full-suite run had 52 clean scenes out of 56: ending/game-over assertions passed but their known intermittent two-object audio shutdown warnings failed the strict runner; TestLevel's missing disabled-timer override was restored and level_timer_test then passed; the movement-handoff failure is resolved by the jump rollback and its clean rerun. The final state has not had a second complete suite run. CI/export and physical-controller qualification were not performed.

## Combined jump timing and landing-depth correction - 2026-11-05

The combined implementation uses current-speed airborne displacement followed by gravity and rejects landing assistance based on projected post-motion depth. The six-position jump benchmark passed headlessly and rendered: an early pipe takeoff misses, near-edge takeoffs reach the staircase, and all tested upper-question-block attempts miss. Its full-speed launch and approximately 82.5-pixel apex assertions pass.

Focused headless coverage includes jump/variable release/weight/ceiling response, corner correction with explicit excessive projected-depth rejection, 44 state handoffs, one-tile gap runs in both directions at five subpixel phases, two-tile gaps onto a lower pipe at eleven phases in both directions, passive animation freezing, climbing capture, and the ledge-camera matrix. The latter now requires 48 accepted landings to preserve horizontal integration and 24 over-depth cases to reject rescue; all 72 verify camera displacement. Rendered camera-wall jumping and flag foreground ordering also pass. Physical-edge fallback probes were retained after removing them caused gap snagging; this remains a documented Godot collision approximation. Early diagnostic failures led to this correction; they are not represented as passing results.

No final full-suite, CI, export, or Mesen ROM trace qualification was performed. A headless camera-wall run with a 900-frame cutoff ended before PASS and reported audio shutdown leftovers; its completed rendered run passed without engine warnings/errors. Local gameplay feel still needs the user's comparison against Mesen. No Git operations were performed.

## Retained falling gravity - 2026-11-05

falling_gravity_test passes headlessly and rendered, covering entrance initialization, all five takeoff profiles (including replacing a fast profile with a slower one), persistence after jump cleanup, passive-fall application, unchanged horizontal coasting, weight/higher-priority overrides, and modifier cleanup. jump_test verifies retained gravity after an actual stationary-jump landing; the six-position full-speed benchmark verifies retention after landing as well as the unchanged launch/apex and requested reach/miss behavior. The benchmark also passes rendered.

Focused headless jump, running-gap, stepped-gap, passive-animation, movement-handoff, general transport, lower-area, ledge-camera, pipe-transfer and death tests passed without engine errors/warnings. lower_area_test explicitly checks failed travel preserves the selected force and committed arrival resets it to 562.5. Formatting checks passed. No final full-suite, CI/export, Mesen frame trace or physical-controller qualification was run. No Git operations were performed.

## Silent time-to-score conversion - 2026-11-05

time_score_test passed headlessly and rendered: thirteen units convert into 650 points over thirteen physics ticks, HUD timer/score values update every tick, the following tick releases the Score gate once, and the captured contact time remains unchanged. It also covers zero/disabled counters, cancellation/stale completion, synchronous level replacement from a timer signal, score saturation and absence of counting-audio children.

flagpole_ending_test passed headlessly and rendered with its full manual-hook lifecycle scenarios and real-music scenario; the latter uses a short counter to verify the existing music-tail/final-hold behavior. Rendered flagpole_draw_order_test also passed. Focused level_completion_test, level_timer_test, hud_test and player_status_test passed headlessly. All nine completed validation logs had PASS and no engine errors/warnings. The initial new-script test required refreshing Godot's class cache before it could resolve TimeScoreStep; final runs resolved it successfully. Formatting and changed script/scene whitespace checks passed.

No full-suite, CI, release-export or original-emulator frame/audio qualification was performed. Timer counting audio remains intentionally absent; other completion audio and the existing final-hold policy are unchanged. No Git operations were performed.

## Final-score promotion on title return - 2026-11-05

player_status_test passed headlessly and rendered, checking a higher outgoing score promotes the title record before reset, ties/lower scores preserve it without duplicate notifications, the title label reflects the record, and direct session reset preserves it. time_score_test passed headlessly through the real finish-to-title flow: 900 starting points plus thirteen timer units become a displayed top score of 1550 before the live score resets. level_completion_test passed for stage carry/cleanup and lower-score record preservation. game_over_test completed all assertions with an outgoing score of 456999 promoting an existing 456789 record, but reported the known intermittent two-object audio shutdown leak warning; this was not a clean strict-suite pass. Formatting checks passed. Full suite, CI/export and disk persistence were not tested or introduced. No Git operations were performed.
