# Verification

Run the complete regression set from the project root, passing the console Godot executable:

```powershell
./scripts/run_tests.ps1 -GodotPath 'C:\path\to\Godot_console.exe'
```

The runner discovers tests/*_test.tscn, uses the normal project/autoload startup at a 60 FPS cap, and bounds each run with --quit-after 1800. A zero exit code alone is insufficient: each scene must print PASS, with no SCRIPT ERROR, ERROR, or WARNING lines. A failed scene makes the command fail. Logs are written under .godot/validation. APPDATA/LOCALAPPDATA overrides are restored afterward.

The current 32 scenes cover:

| Area | Coverage |
| --- | --- |
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
| Area themes | Independent TileSets, all 18 Underground texture mappings, terrain collisions, both pipes, question animation/used art, themed previews, decoration fallback, resource isolation, inherited bounce, and shutdown |
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
