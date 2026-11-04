# Backlog

This guide records deferred work, not implemented features.

## Next session - 2026-11-04

Update 2026-11-04: shared player status and live HUD/title/intro bindings are implemented first. See [player status](player-status.md). Top-score promotion/saving, coin rollover/rewards, timer countdown, life deduction/game over and form-based scene selection remain deferred.

Requested next priorities:

1. Add collectible coins, reusing the shared animation clock and area themes. Define collection, GameHandler-owned coin totals/HUD updates, and progress persistence using the existing death-reset policy.
2. Add our first enemy using the existing BaseEntity/state machine and area-owned EnemySpawner. Agree on the enemy and its initial behavior, then verify camera-buffer spawning/disposal, return/death behavior and player interactions against the reference.

Start with coins, then the first enemy. These are planned tasks; implementation has not started.

Update 2026-11-03: pit death, shared gameplay suspension, cleanup, death event audio and PlayerSpawn restart are now implemented. The agreed global reset_progress_on_death=false replaces the per-level default-true proposal below. See [death lifecycle](death.md). Remaining work: visible hit-death presentation and general off-camera entity policies.

Update: [BaseArea camera activity and enemy spawner foundation](entity-activity.md) are implemented with resident-object sleep and reentry-based disposable actors. Remaining: actual enemy scenes/AI, enemy-specific respawn and defeat persistence, state-driven callback scheduling inside the activity region, and profiling with hundreds of objects before considering spatial indexing. Visible hit-death presentation remains deferred.

## P2: Standalone level death cannot restart

Status: open; reproduced during PR review on 2026-11-03 and deferred to the backlog at the user's request.

Reproduction: open scenes/levels/1-1.tscn, run the current scene with F6, and fall into a pit. Mario is shut down/removed and world gameplay is suspended. When death finishes, BaseLevel._restart_after_death rejects the restart because GameHandler.current_level does not own this standalone level. The restart has already been marked queued, leaving the scene frozen without a player.

Affected code: [BaseLevel](../scenes/levels/base/base_level.gd), especially on_death, _update_death and _restart_after_death. The normal Game-owned F5 restart path has passing regression coverage; the missing path is standalone execution.

Decide and implement an explicit standalone policy: support restarting the directly run level, or reject/disable unsupported death before destructive cleanup. Preserve the ownership guard that prevents an old level from restarting over a replacement game session.

Acceptance checks:

- Exercise standalone F6 pit death through completion; no permanent frozen, playerless scene.
- Verify the chosen standalone behavior with and without death audio.
- Retain F5 PlayerSpawn restart, both global world-progress policies and unchanged lives.
- Verify duplicate death and stale completion cannot reload or overwrite another level.
- Add focused regression coverage and update the death guide with the supported standalone contract.

## Restore area music when suitable sound files are available

Status: deferred at the user's request on 2026-11-02. Suitable soundtrack files are not ready. Area music playback, theme music fields/assignments and the Music Enabled override have been removed. Generic area entry/exit and active-area tracking remain. Existing soundtrack files are retained unassigned; their presence is not approval to use them again. Entity sound effects remain enabled.

### Asset prerequisites

- Select final Overworld and Underground tracks and confirm their source and permitted project use.
- Audition complete tracks and repeated loop boundaries for silence, clicks, truncated notes, lead-ins and trailing silence. A loop flag alone does not make an unsuitable recording seamless.
- Decide whether each asset is a seamless full-file loop or requires explicit loop points/introduction handling. Verify the chosen format and Godot implementation support that requirement.
- Compare loudness, clipping and balance against jump, skid, bonk and pipe effects. Decide on gain and any dedicated Music bus before implementation; request approval for Project Settings, bus or import-setting changes.
- Record final asset paths, format, loop expectations and any deliberate import changes. Do not rename/reuse temporary files merely because an old reference exists.

### Proposed ownership and behavior to restore

- AreaTheme supplies an optional track and loop/volume configuration; BaseLevelArea owns a separate non-positional soundtrack player, independent of exclusive entity SFX.
- Restore a per-area Music Enabled override for silent test rooms. Missing tracks and disabled areas remain silent.
- BaseLevel's existing enter_area/exit_area calls are the integration points. Loading or validating a destination must not start music; only committed occupancy activates it.
- Stop source playback before starting destination playback. Same-area travel should not restart music; returning from another area should initially restart from the beginning unless a different policy is explicitly chosen.
- Stop and release playback on area exit, unload, terminal level shutdown, tree removal and synchronous level replacement. Queued completion from an old track must not restart playback or change the new session.
- Keep source resources isolated. If runtime loop configuration is used, copy streams instead of mutating shared imported resources.
- Define active-theme changes and enable/disable toggles without duplicate players or accidental restarts on repeated assignments.

These describe the previous intended contract, not a commitment to reuse every implementation detail. Reassess against the final assets and death lifecycle.

### Decisions before implementation

- Exact loop mechanism, supported formats and whether intros need a separate segment.
- Hard track changes versus crossfades, and whether identical tracks continue across different areas.
- Pause behavior and volume/mute ownership; session settings versus area authoring defaults.
- Death, respawn, game-over, victory and other stingers: who owns playback and how they interrupt/resume area music. The fall-death milestone must not depend on music being restored first.
- Whether playback positions are ever retained across area visits; disk persistence is out of scope unless requested.

### Implementation and acceptance checks

1. Import and manually audition the approved assets, including several consecutive loops and transitions on the real audio device.
2. Add only the agreed theme/area configuration and lifecycle playback. Keep SFX independent and preserve current area streaming/transport ownership guards.
3. Restore dedicated music tests: audible decoding, loop behavior across actual track end, startup, preload silence, same-area continuity, cross-area non-overlap, return, missing tracks, per-area disable/toggles, resource isolation, replacement and cleanup.
4. Test death/respawn integration against whichever lifecycle exists then. Confirm no duplicate soundtrack or stale callback after rapid transitions/shutdown.
5. Retain focused area lifecycle tests even without sound assets. Decide whether shared silent fixtures are still needed; they currently retain their existing paths but have no music overrides.
6. Update current area/theme/transport guides, settings where applicable, verification and milestone history. Distinguish headless decoding/state checks from audible loop quality and speaker output.

Completion requires suitable files and audible validation; the previous decode/loop-flag assertions did not establish seamless playback. Crossfades, loop points, buses and death music remain proposals until implemented and verified.

## Intermittent camera hitch at 240 Hz

Open: capture the reported occasional hitch during normal play with [the opt-in frame pacing scene](frame-pacing.md). Automated 240 FPS traversal did not reproduce a delayed frame or interpolation mismatch. Correlate a visible hitch with frame intervals, camera progress and engine timing before changing VSync, physics, viewport, interpolation or renderer settings. Host render completion is not display scanout evidence.

## Native engine shutdown failures after PASS

Open after the SFX balance milestone (2026-11-03): the 41-scene run had scene_hierarchy_test print PASS but exit -1073741819 (Windows access violation). Its unchanged focused rerun exited zero. The earlier runtime coordinator loading change passed a 100-launch probe and a full suite, but subsequent evidence shows native shutdown is not fully resolved. Do not equate a PASS line with a successful process exit, or classify the full run as clean after a rerun. Runner exit/error checks remain strict.

Investigate engine/resource shutdown lifetime with a reduced scene save/reload reproducer and native crash evidence. Establish whether a supported engine fix or a specific project lifetime correction is necessary; discuss any engine/project-setting changes before applying them. Retain all regression assertions and avoid retries that mask crashes. This issue is separate from the intermittent user-visible camera hitch and from SFX gain application.
