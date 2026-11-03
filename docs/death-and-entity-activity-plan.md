# Planned death lifecycle and off-camera entity activity

Status updated 2026-11-03: pit death, shared suspension, player cleanup, death SFX and PlayerSpawn restart are implemented; see the [current death guide](death.md). The global GameHandler.reset_progress_on_death flag defaults to false (preserve world progress), superseding the per-level default-true proposal below. Visible Mario hit-death presentation, lives/game over and general off-camera policies remain planned. The earlier design below is retained as planning context where not superseded.

## Completed first milestone: falling death

BaseLevel now coordinates pit detection, world suspension, player cleanup, level-owned death audio and restart. GameHandler.reset_progress_on_death=false is the global configuration; it preserves world progress by default. This supersedes the former per-level default-true proposal. See [death lifecycle](death.md) for current behavior and limitations. Visible Mario hit-death presentation and other death causes remain future work.

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

Update current guides and verification when these features are implemented. Death and shared suspension now have regression coverage; see the current guide. General off-camera activation/disposal features remain unimplemented and unqualified.
