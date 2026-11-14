# Super Mario GD

A Godot 4.7 platformer tutorial and reference in the QuickReference series. World 1 stages 1-1 through 1-4 share reusable scenes, entity state machines, and 16×16 terrain and enemy placement grids. Play from the title screen through the overworld, underground, treetop, and castle stages.

## Run the game

1. Open `project.godot` in Godot 4.7.
2. Press **F5** to launch the title screen.
3. Use **Tab** or controller **Select** to choose **1 PLAYER GAME** for Mario or **2 PLAYER GAME** for a solo Luigi run, then press **Enter** or controller **Start** to play 1-1. Play through 1-1, 1-2, and 1-3 to reach Bowser’s castle in 1-4. Clearing 1-4 returns to the title.

| Action                | Keyboard            | Controller             |
| --------------------- | ------------------- | ---------------------- |
| Move                  | Left / Right arrows | D-pad                  |
| Jump                  | Space               | A / bottom face button |
| Run                   | Left Shift          | X / left face button   |
| Enter a vertical pipe | Down                | D-pad Down             |
| Pause / resume        | Enter               | Start / Menu           |

Hold Jump for more height, and press the opposite direction while running to skid. Enter a pipe to see the camera, palette, and music switch together. Reach the flagpole to see the score popup, castle walk, and time-to-score conversion.

## What the project demonstrates

- **Player movement and state machines.** Mario owns his movement states and animations. Reusable actions and motion components handle running, jumping, and collision responses.
- **Paintable entities.** Place coins, blocks, pipes, and flagpoles on the same grid as the terrain. The level creates the corresponding scene instances when the area loads. Hit a question block from below for its configured reward; Super Mario can shatter ordinary bricks for debris and 50 points.
- **Area and session lifecycle.** BaseLevel coordinates its death, timer, transport, area-content, and spawn-registry helpers. Areas own cameras, palettes, music, and activity boundaries. Used question blocks and collected coins can persist across area changes, while ordinary bricks and enemies reset.
- **Shared entity behavior.** BaseEntity owns lifecycle and input, with reusable theme application and activity bookkeeping. Nested enemies remain independent of their sleeping spawners.
- **HUD and audio.** An 8×8 bitmap HUD follows session state and area palettes. Synthesized effects share playback voices where appropriate, and background music restarts on area transitions.

## Explore in the editor

Open `scenes/levels/worlds/world 1/1-1.tscn` and expand **Areas → MainArea → Layouts** to inspect terrain, scenery, and entity stamps. Open `scenes/player/mario/mario.tscn` to see how the player combines its state machine, motion components, and actions.

Open `scenes/levels/worlds/world 1/1-1.tscn` and press **F6** to run 1-1 directly.

## Checks

Run focused headless regression scenes from PowerShell:

```powershell
./scripts/run_tests.ps1 -GodotPath 'C:/path/to/Godot_console.exe' -TestName @('block_test', 'area_streaming_test')
```

See [Testing](docs/testing.md) for individual scenarios and manual checks.

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
