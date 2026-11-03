# Planned death lifecycle and off-camera entity activity

Status: planning only, agreed direction recorded on 2026-11-02. None of the death hooks, reset configuration, respawn flow, or entity activity policies below is implemented yet. Existing area unloading and progress restoration remain available.

## First milestone: falling death

Start with falling below the active camera viewport. Enemy damage, hazards, death UI, lives, checkpoints and game-over behavior are later work.

BaseLevel will coordinate a guarded `on_death(player)` lifecycle entry point that future hazards can also call. The exact GDScript API/signature is to be settled during implementation. The player owns its death presentation; GameHandler owns shared session data and saved world progress; the active area owns its camera and occupancy lifecycle. Area music is currently removed; restoration is tracked in the [backlog](backlog.md).

Proposed sequence: Playing -> Death triggered -> Death presentation -> Restart -> Playing.

1. During physics, compare the player's world-space bounds with the active camera's bottom edge. Trigger after the player has fallen fully below the viewport. Do not add a bottom clamp that pushes the player back on screen. Confirm the cutoff and timing against the decompiled reference before choosing constants.
2. Accept death once for the current player/level. Reject duplicate calls, shutdown/stale ownership, and requests during transport. Death is a gameplay phase, separate from terminal shutdown.
3. Lock controls and discard pending actions, freeze camera tracking, and notify GameHandler. Music interruption is deferred until soundtrack support returns; death must work without it. Verify the reference's fall-death timing and audio sequence before implementing exact presentation details; these are not established parity claims.
4. Let the concrete player complete its death presentation through a reusable player contract/state. Falling off-screen must not reposition Mario into view for an enemy-hit death hop. A future damage death may use a different presentation.
5. At completion, apply the level's progress-reset policy, reload/restart the level and spawn at the real PlayerSpawn. Use existing shutdown/cleanup for removed objects. Guard delayed completion against duplicate callbacks or level replacement, as with transport.

The initial restart target is PlayerSpawn. Checkpoint selection and life exhaustion are deferred. Death-specific music/SFX assets and timing still need inspection; do not assume a particular supplied asset exists.

## Agreed configuration: progress on death

Add this exported BaseLevel property during the death milestone:

```gdscript
@export var reset_progress_on_death: bool = true
```

This is planned scene configuration, not a currently available Inspector property or a Project Settings change.

- Enabled (default): clear this level's saved world progress before restarting, restoring used/broken blocks and collected world coins to their authored layout.
- Disabled: retain this level's saved world progress through restart, restoring used/broken blocks and removed collected coins as they were before death.

GameHandler owns clearing/preserving the stored progress; BaseLevel supplies the policy. Apply it across all areas of this level, including the active area's latest state, without clearing unrelated levels. Ensure shutdown/unload cannot write an old snapshot back after a reset. Ordinary pipe travel continues preserving progress regardless of this flag.

This flag governs world state only. Score, the player's coin counter, lives, power-ups and checkpoints need separate policies; resetting a world coin does not by itself define what happens to a session counter. Collectible coins and their progress records are not implemented yet, so they must join this contract when added.

## Second milestone: off-camera entity activity

Keep this separate from the first death implementation. Proposed editable BaseEntity policies:

| Policy | Intended use | Behavior |
| --- | --- | --- |
| Always active | Essential world logic | Continue processing outside view |
| Suspend outside view | Reusable enemies and animated objects | Pause gameplay processing and resume on return |
| Dispose outside view | Debris, projectiles and temporary effects | Run terminal shutdown and free |
| Activate on approach | Painted enemies not yet encountered | Defer instantiation until the camera approaches |

The last policy requires level/entity-layout spawning support; a not-yet-created entity cannot manage its own activation. Policy names, defaults, margins and implementation mechanism remain proposals.

Use the active camera with an activation margin and separate suspension distance to prevent repeated toggles near an edge. Decide dimensions and margins during implementation. Disabling physics saves CPU, not object memory; freeing or deferring instantiation saves memory. Existing whole-area unloading already frees inactive layouts, entities, collisions and cameras while retaining routing metadata and progress.

Suspension is reversible and must not invoke terminal shutdown. Define which physics, regular processing, animation, timers and global input/event listeners pause, and resume without duplicate subscriptions. Global signals can still invoke callbacks when physics processing is disabled. Retain collision for suspended solid objects unless a specific entity design requires otherwise. Blocks that already do not run physics every tick need no extra physics-pause machinery.

Disposal of painted entities requires an explicit respawn/persistence policy so area recreation does not unexpectedly respawn them or permanently remove them. Temporary effects and authored world objects need different defaults; these are not decided yet.

## Implementation checkpoints and verification

First implement and inspect fall death, then add shared entity activity with a small test entity before applying it broadly.

Death checks should cover both area cameras, one-time triggers, control/camera locks, falling versus future hit presentation, progress reset on/off across areas, spawn restoration, cleanup and stale completion after level replacement. Verify ordinary transport still preserves progress and cannot overlap death ownership.

Entity activity checks should cover margins, stable pause/resume, callback gating, retained solid collision, once-only disposal, authored-object persistence and coexistence with whole-area unloading. Avoid adding per-frame work to static entities solely to disable callbacks they never had.

Update current guides and verification when these features are implemented. This document records the next-work plan; no death or off-camera feature tests have been run because these features do not exist yet.
