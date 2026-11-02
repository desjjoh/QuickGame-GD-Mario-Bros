# QuickGame-Godot2D (Super Mario Bros)

A Godot 4.7 reference project exploring a 2D platformer inspired by Super Mario Bros., with 16×16 tiles and sprites.

Game loads TestLevel through a global handler. Mario's Idle/Move/Slide/Jump states orchestrate horizontal movement, Run, and skid actions using shared per-player motion values. Move plays a three-pose walk/run loop with velocity-based cadence; Idle and Slide use static poses. Variable jumping, solid-ceiling bumps, exclusive entity sound effects, horizontal camera bounds, and a combined outer shadow are implemented. Levels and entities have explicit terminal shutdown; startup still uses _ready(). Right-only horizontal camera scrolling is implemented; enemies, power-ups, disk saves, and respawn are not implemented. Current movement is an approximation, not original-game physics parity.

## Run

Open `project.godot` in Godot 4.7 and press **F5**. The configured main scene is `scenes/main/game.tscn`. Open `scenes/levels/test_level.tscn` to inspect the floor and spawn marker, or `scenes/player/mario (small)/mario.tscn` to inspect the player and Idle state.

Use left/right arrows to move; hold Left Shift or the gamepad left face button to run. Release direction to brake. Press Space (primary) to jump; hold for a higher jump. The camera scrolls right as Mario advances and does not scroll back. Falling has no automatic respawn. Restart with F8 then F5 to reset his position.

Press the opposite direction while moving to skid. Slide preserves momentum and brakes before reversing. Releasing direction retains the skid pose until stopping; actively resuming the original travel direction cancels the skid. No crouching slide or new input binding is involved.

## Documentation

| Reference | Purpose |
| --- | --- |
| [Architecture](docs/architecture.md) | Current ownership, scene hierarchy, and startup flow |
| [State machine](docs/state-machine.md) | State hooks, presentation, controls, and verification |
| [Movement](docs/movement.md) | Shared motion values, run modifiers, source conversions, and fidelity limits |
| [Jumping](docs/jumping.md) | Jump state, passive falling in Move, variable jump height, gravity, weight, and takeoff profiles |
| [Decisions](docs/decisions.md) | Architectural choices, reasons, tradeoffs, and proposals |
| [Settings](docs/settings.md) | Deliberate configuration changes and approval history |
| [History](docs/history.md) | Dated implementation and verification record |

Documentation records important milestones, major implementations, architectural decisions, and deliberate settings changes under the [repository working agreements](AGENTS.md). Routine code edits do not require individual entries. Current guides describe the present implementation; historical entries retain the context of earlier choices.


## Checks

Run all regression scenes with ./scripts/run_tests.ps1 -GodotPath 'C:\path\to\Godot_console.exe'. See [verification](docs/verification.md) for coverage and limits.

