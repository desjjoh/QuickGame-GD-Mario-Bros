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
- The Game scene supplies the stage list and the shared shadow master toggle. The first stage is 1-1. Open `scenes/main/game.tscn`, select **Game**, and use **Presentation → Shadow Style** to load `assets/shadows/soft.tres`, `crisp.tres`, or `outer_blur.tres`. Clear the field for no shadow effect. Soft is the Game default. One selection applies to the title and every stage; standalone F6 previews read the saved Game selection and master toggle. Decorations remain outside the effect.

Historical setting changes and their approvals are in the [settings record](archive/settings.md).

## Known reference differences

Super Mushroom is available in the existing **EntityLayout** block reward brush: choose **Apply Super Mushroom Reward**, then click a painted question block, hidden question block, reward brick, or alternate reward brick. Its translucent red-mushroom indicator stays visible with the other reward previews. Coin remains the default. This assigns an explicit Super Mushroom, not an automatic mushroom/flower tier.

Super Mushroom always grants 1,000 points. Small Mario grows; already-Super Mario stays Super until Fire is implemented. The latter is the approved temporary difference from the NES's status-based Fire upgrade. See [Super Mushroom](archive/super-mushroom.md).

Timed multi-coin rewards use independent, fixed 231-physics-tick windows instead of the NES's shared, phase-dependent timer. Loading or hitting another block cannot alter an existing window. Pause and unloaded areas freeze remaining time; death follows the existing progress-reset policy. See the [reference investigation and version differences](archive/timed-coin-research.md#approved-version-difference).

## Shared entity registry

Add standard marker-to-scene mappings to **BaseLevel: Entity Scenes** in scenes/levels/base/base_level.tscn. TestLevel and 1-1 inherit this registry. Do not create a per-level dictionary override: Godot replaces the inherited dictionary rather than merging entries. Levels own their painted placements and reward overrides.
