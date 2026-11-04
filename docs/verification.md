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

Integration tests retain `tests/fixtures/silent_game.tscn` and `silent_level.tscn` as shared inherited fixtures, now without music overrides. area_music_test retains its existing entry point but checks silent area lifecycle behavior; it no longer decodes soundtrack assets. Music playback and audible-loop qualification are deferred in the [backlog](backlog.md).

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
