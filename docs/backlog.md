# Backlog

This guide records deferred work, not implemented features.

## Next session - 2026-11-04

Update 2026-11-03: pit death, shared gameplay suspension, cleanup, death event audio and PlayerSpawn restart are now implemented. The agreed global reset_progress_on_death=false replaces the per-level default-true proposal below. See [death lifecycle](death.md). Remaining work: visible hit-death presentation and general off-camera entity policies.

Next work: general off-camera entity activity. Start from the [remaining plan](death-and-entity-activity-plan.md#second-milestone-off-camera-entity-activity). Define camera margins and reversible suspension versus terminal disposal/deferred activation. Shared suspension now exists, but automatic visibility tracking and enemy respawn/persistence policies do not. Enemies remain unimplemented. Work in small checkpoints with a test entity; visible hit-death presentation is also still deferred.

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
