# Configuration

## Project settings

| Setting | Value |
| --- | --- |
| Main scene | `scenes/main/game.tscn` |
| Logical viewport | 256×240 |
| Initial window | 768×720, borderless |
| Stretch | Viewport mode with integer scaling |
| Physics interpolation | Enabled |
| Windows rendering driver | Direct3D 12 |

Use Godot’s **Project → Project Settings → Input Map** to inspect bindings. See [setup](setup.md#controls) for gameplay controls.

## Areas and pipe routes

Select a `BaseLevelArea` and set its **Theme** to Overworld, Underground, or Castle. The theme supplies compatible ground, decoration, and entity TileSets, plus entity and UI artwork. Keep source IDs and atlas coordinates compatible across themes so painted layouts survive a theme change.

Set **Background Music** independently to Overworld, Underground, or None. Overworld is the default. 1-1 uses Underground in its secret area. Test Level uses None.

Set **Transport Points** and **Pipe Routes** on the source area to link placed pipes to explicit area and destination IDs. A destination pipe supplies its exit pose. The reserved `player_spawn` target returns to the main area’s spawn. Standalone arrival markers are useful where an area needs a separate landing point.

## Level rules

- Set camera world bounds on the area camera to define the playable scroll range.
- Set the timer limit and enable flag on the level. A disabled timer hides the number and keeps the TIME label.
- `GameHandler.reset_progress_on_death` controls whether death clears progress. Each entity’s persistence setting applies to both death and area reload.
- The Game scene supplies the stage list and the shared shadow toggle. The first stage is 1-1.

Historical setting changes and their approvals are in the [settings record](archive/settings.md).

## Known reference differences

Timed multi-coin rewards use independent, fixed 231-physics-tick windows instead of the NES's shared, phase-dependent timer. Loading or hitting another block cannot alter an existing window. Pause and unloaded areas freeze remaining time; death follows the existing progress-reset policy. See the [reference investigation and version differences](archive/timed-coin-research.md#approved-version-difference).
