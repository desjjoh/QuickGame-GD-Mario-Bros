# QuickGAME-GD Mario Bros

A Godot 4.7 platformer tutorial and reference in the QuickReference series. The playable 1-1 stage brings reusable scenes, entity state machines, and a 16×16 level grid together in a complete title-to-stage-clear flow.

## Run the game

1. Open `project.godot` in Godot 4.7.
2. Press **F5** to launch the title screen.
3. Press **Enter** or controller **Start** to play 1-1.

| Action                | Keyboard            | Controller             |
| --------------------- | ------------------- | ---------------------- |
| Move                  | Left / Right arrows | D-pad                  |
| Jump                  | Space               | A / bottom face button |
| Run                   | Left Shift          | X / left face button   |
| Enter a vertical pipe | Down                | D-pad Down             |

Hold Jump for more height, and press the opposite direction while running to skid. Enter a pipe to see the camera, palette, and music switch together. Reach the flagpole to see the score popup, castle walk, and time-to-score conversion.

## What the project demonstrates

- **Player movement and state machines.** Mario owns his movement states and animations. Reusable actions and motion components handle running, jumping, and collision responses.
- **Paintable entities.** Place coins, blocks, pipes, and flagpoles on the same grid as the terrain. The level creates the corresponding scene instances when the area loads.
- **Area and session lifecycle.** Areas own their cameras, palettes, and background tracks. Used question blocks and collected coins can persist across area changes, while bricks reset.
- **HUD and audio.** An 8×8 bitmap HUD follows session state and area palettes. Synthesized effects share playback voices where appropriate, and background music restarts on area transitions.

## Explore in the editor

Open `scenes/levels/worlds/world 1/1-1.tscn` and expand **Areas → MainArea → Layouts** to inspect terrain, scenery, and entity stamps. Open `scenes/player/mario (small)/mario.tscn` to see how the player combines its state machine, motion components, and actions.

For a one-screen sandbox, open `scenes/levels/test_level.tscn` and press **F6**.

## Documentation

| Guide                                  | Contents                                           |
| -------------------------------------- | -------------------------------------------------- |
| [Setup](docs/setup.md)                 | Run the game, learn the controls, and edit a level |
| [Architecture](docs/architecture.md)   | Scene ownership, gameplay lifecycle, and audio     |
| [Configuration](docs/configuration.md) | Project settings, area themes, routes, and rules   |
| [Testing](docs/testing.md)             | Headless regressions and manual checks             |
| [Security](docs/security.md)           | Local data and trust boundaries                    |
| [Deployment](docs/deployment.md)       | Windows export and release checks                  |
| [Backlog](docs/backlog.md)             | Open work and known issues                         |

## Checks

Run the headless regression scenes from PowerShell:

```powershell
./scripts/run_tests.ps1 -GodotPath 'C:/path/to/Godot_console.exe'
```

See [Testing](docs/testing.md) for individual scenarios and manual checks.

## License

[MIT](LICENSE).
