# QuickGame-Godot2D (Platformer)

A Godot 4.7 platformer tutorial and reference project in the QuickReference series, exploring techniques from multiple games with reusable scenes, entities, and state machines. The current playable example uses Mario with 16Ã—16 tiles and sprites.

GameHandler opens a title screen over TestLevel; Start loads 1-1 through the existing transition lifecycle. Mario's Idle/Move/Slide/Jump states orchestrate horizontal movement, Run, and skid actions using shared per-player motion values. Move plays a three-pose walk/run loop with velocity-based cadence; Idle and Slide use static poses. Variable jumping, solid-ceiling bumps, exclusive entity sound effects, horizontal camera bounds, and a combined outer shadow are implemented. Levels and entities have explicit terminal shutdown; startup still uses _ready(). Right-only horizontal camera scrolling is implemented; enemies, power-ups, disk saves and checkpoints are not implemented. Accepted death reduces reserve lives; nonnegative reserves respawn at PlayerSpawn and negative reserves show GAME OVER with sound before returning to title. Current movement is an approximation, not original-game physics parity.

## Run

Open `project.godot` in Godot 4.7 and press **F5**. The configured main scene is `scenes/main/game.tscn`. The title opens first; press Enter or controller Start/Menu to begin. Open `scenes/levels/worlds/world 1/1-1.tscn` to inspect the floor and spawn marker, or `scenes/player/mario (small)/mario.tscn` to inspect the player and Idle state.

Use left/right arrows to move; hold Left Shift or the gamepad left face button to run. Release direction to brake. Press Space (primary) to jump; hold for a higher jump. The camera scrolls right as Mario advances and does not scroll back. Falling fully below the active camera triggers death, freezes gameplay, plays the death sound and restarts at PlayerSpawn. World progress is preserved by default through GameHandler.reset_progress_on_death=false.

Press the opposite direction while moving to skid. Slide preserves momentum and brakes before reversing. Releasing direction retains the skid pose until stopping; actively resuming the original travel direction cancels the skid. No crouching slide or new input binding is involved.

## Documentation

| Reference | Purpose |
| --- | --- |
| [Animation clock](docs/animation-clock.md) | Shared cosmetic phases, late joins and future coin setup |
| [UI and HUD](docs/ui.md) | Persistent screen layer, 8x8 bitmap text, live values and themed animated coin |
| [Architecture](docs/architecture.md) | Current ownership, scene hierarchy, and startup flow |
| [Area themes](docs/level-themes.md) | Area-owned layouts, palette selection, compatible TileSets, and artwork fallback |
| [Area lifecycle](docs/areas.md) | Active-only runtime loading, area unload, and GameHandler progress restoration |
| [Pipes](docs/pipes.md) | Paintable entrances, animation, sound, and exit behavior |
| [Transport](docs/transport.md) | Explicit destinations, per-cell routes, area loading, and presentation ownership |
| [State machine](docs/state-machine.md) | State hooks, presentation, controls, and verification |
| [Movement](docs/movement.md) | Shared motion values, run modifiers, source conversions, and fidelity limits |
| [Jumping](docs/jumping.md) | Jump state, passive falling in Move, variable jump height, gravity, weight, and takeoff profiles |
| [Game over](docs/game-over.md) | Reserve lives, game-over presentation/audio and one-level progress cleanup |
| [Death lifecycle](docs/death.md) | Pit detection, suspension, cleanup, death sound, restart and global progress policy |
| [Death and entity activity plan](docs/death-and-entity-activity-plan.md) | Planned fall-death lifecycle, progress-reset policy, and off-camera entity management |
| [Code style](docs/code-style.md) | GDScript formatting commands, cleanup checks and remaining lint debt |
| [Backlog](docs/backlog.md) | Deferred features and prerequisites, including restoring area music |
| [Decisions](docs/decisions.md) | Architectural choices, reasons, tradeoffs, and proposals |
| [Settings](docs/settings.md) | Deliberate configuration changes and approval history |
| [History](docs/history.md) | Dated implementation and verification record |

Documentation records important milestones, major implementations, architectural decisions, and deliberate settings changes under the [repository working agreements](AGENTS.md). Routine code edits do not require individual entries. Current guides describe the present implementation; historical entries retain the context of earlier choices.


## Checks

Run all regression scenes with ./scripts/run_tests.ps1 -GodotPath 'C:\path\to\Godot_console.exe'. See [verification](docs/verification.md) for coverage and limits.


## Area artwork

1-1/Areas/MainArea selects Overworld and Areas/LowerArea selects Underground. Paint through the chosen area's Layouts group. Underground supplies ground, solid blocks, both bricks, question-block animation/used art, and all pipe sections with matching paint previews; all 15 decoration pieces have matching Underground artwork. Area themes reuse the existing entity scenes and behaviors. See [area themes](docs/level-themes.md) for configuration.

Paint Pipe entrance (2x2) in an area's EntityLayout, stand centered on it, and hold Down to teleport to LowerArea. Configure explicit destinations through each area's Transport Points array. Destination pipes provide their own exit positions without separate arrival markers. Entry moves behind the pipe with sound before the camera handoff. The secret-area sideways entrance returns directly to PlayerSpawn. See [pipes](docs/pipes.md).

Only the occupied area keeps runtime layouts, entities, collisions, and camera loaded. Inactive endpoint/configuration metadata remains available; GameHandler preserves area progress for return visits. All areas remain visible for editing in the local scene.

Area music is deferred pending suitable sound files; see the [music restoration backlog](docs/backlog.md#restore-area-music-when-suitable-sound-files-are-available). Area entry/exit hooks remain available; entity SFX are unchanged.

Game owns a persistent 8x8-grid HUD above world content and below Mario. World, HUD and player share one soft-shadow composite. Score, coin, stage and time displays read GameHandler values through signals; the animated coin follows the active area theme. The timer does not count down yet. See [UI and HUD](docs/ui.md).

HUD coin and active question blocks sample a global 48-tick cosmetic cycle, so newly loaded objects stay synchronized. Walking and action animations retain their local timing.

Global [transitions](docs/transitions.md) cover area/theme swaps with full black including HUD, and bracket the initial/respawn splash with quick black phases.

`scenes/levels/worlds/world 1/1-1.tscn` is the existing connected stage. `scenes/levels/test_level.tscn` is the one-screen sandbox and title background: one Overworld area and fixed 256x240 camera. F6 permits normal isolated testing; title use suspends Mario. The menu uses the white HUD font and a single-player cursor. Press Enter or controller Start/Menu to enter 1-1. See [title flow](docs/title-screen.md).
