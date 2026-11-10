# Configuration

## Project settings

| Setting | Value |
| --- | --- |
| Main scene | `scenes/main/game.tscn` |
| Logical viewport | 256×240 |
| Initial window | 768×720, bordered and resizable |
| Stretch | Window-resolution `canvas_items`, fractional scaling with aspect preserved |
| Physics interpolation | Enabled |
| Windows rendering driver | Direct3D 12 |

Use Godot’s **Project → Project Settings → Input Map** to inspect bindings. See [setup](setup.md#controls) for gameplay controls.

## Areas and pipe routes

Select a `BaseLevelArea` and set its **Theme** to Overworld, Underground, or Castle. The theme supplies compatible ground, decoration, and entity TileSets, plus entity and UI artwork. Keep source IDs and atlas coordinates compatible across themes so painted layouts survive a theme change.

Set **Background Music** independently to Overworld, Underground, or None. Overworld is the default. 1-1 uses Underground in its secret area.

Set **Transport Points** and **Pipe Routes** on the source area to link placed pipes to explicit area and destination IDs. A destination pipe supplies its exit pose. The reserved `player_spawn` target returns to the main area’s spawn. Standalone arrival markers are useful where an area needs a separate landing point.

For 1-2's opening, **Presentations → PipeOpening** identifies the intro area and painted castle cell. A fresh entry spawns at the castle's doorway. The sideways pipe targets `main / player_spawn`, so moving **Players → PlayerSpawn** changes both the first underground arrival and the early respawn.

## Area background colour

Select an area such as **Areas → MainArea** and set **Background → Background Color**. Its fill spans **Camera2D → Area Left** and **Area Right**, measured in pixels from the area's origin, and the camera's visible vertical height. Moving the area moves the fill and horizontal camera limits together. Alpha zero reveals Game’s black backdrop during F5; standalone F6 retains the viewport default unless an area supplies a colour. Each area owns its colour independently of its theme and music. The fill sits behind decorations, receives foreground shadows, and never casts a shadow itself in F5 or standalone F6.

## Start-menu background

Open `scenes/main/game.tscn`, select **Game**, and assign **Presentation → Title Background** to the BaseLevel scene you want behind the start menu. An empty field uses the first entry in **Stages**; the authored Game leaves it empty, so its backdrop is 1-1. The selection is used on startup and on later returns to the menu; title actors remain suspended and background music stays silent. Choose a valid level scene, not the title UI scene. Gameplay still loads from **Stages**, independently of this background.

## Level rules

- Set **Area Left** and **Area Right** on the area camera to define the playable scroll range. A one-screen area starting at its origin uses 0 and 256, wherever it sits in the level scene.
- Set the timer limit and enable flag on the level. The HUD keeps the TIME label and hides the digits on the start screen, during transitions such as level intro, TIME UP, and GAME OVER, and whenever the timer is disabled.
- Hurry-up plays once when the timer falls from 100 to 99. A timed stage authored at 1–99 plays the warning at gameplay reveal and then uses the fast music. Starting below 100 is a deliberate extension for authored stages.
- In `scenes/main/game.tscn`, select **Game → Gameplay → Save Entity State Through Death**. Enabled by default, it carries saved entity state and runtime tile changes into the next attempt. Disable it to reload the stage's authored state after a death. Each entity's persistence setting still controls what is saved between area visits. Score and coins in the HUD carry forward in either mode, and death still costs a life.
- The Game scene supplies the stage list and the shared shadow master toggle. The first stage is 1-1. Open `scenes/main/game.tscn`, select **Game**, and use **Presentation → Shadow Style** to load `assets/shadows/soft.tres`, `crisp.tres`, or `outer_blur.tres`. Clear the field for no shadow effect. Outer Blur is the current authored Game selection. One selection applies to the title and every stage; standalone F6 previews read the saved Game selection and master toggle. Decorations remain outside the effect.

### Halfway restarts

Add a `Marker2D` under **Players** at the desired feet position and assign it to the level's **Death → Halfway Spawn** field. On **Areas → MainArea → Camera2D**, enable **Halfway Restart → Halfway Check Enabled** and set **Halfway Camera Left** in pixels from the main area's origin. The 2D editor draws a labeled dashed guide that moves with the area. At life loss, the active camera and the threshold are compared in world coordinates.

1-1 uses a marker at `(1344, 208)` and a camera-left threshold of `1280`. A halfway restart snaps the camera to X=1280 and places Mario's sprite 56 px from the left edge. This places Mario 16 px farther right than the NES halfway restart while keeping page 5 in view. A death before the threshold uses the normal spawn, with camera framing clamped by the main area's bounds. The authored secret room is before the threshold. If a side area's camera is placed at or beyond the threshold, death there uses the halfway marker.

## Known reference differences

Choose **Apply Tiered Power-Up Reward** in the **EntityLayout** block reward brush, then click a painted question block, hidden question block, reward brick, or alternate reward brick. The translucent red mushroom marks the tiered reward. The block chooses a Super Mushroom for Small Mario or Luigi and a Fire Flower for Super or Fire when it releases the reward. Previously painted Super Mushroom assignments use the same tiered behavior. Coin remains the default.

Both items grant 1,000 points on pickup. Super Mushroom grows Small to Super. Fire Flower grows Small to Super, upgrades Super to Fire, and grants points to an already-Fire player.

Choose **Apply Starman Reward** in the same brush to paint a fixed star reward. The translucent star uses the area's item art. Starman can be collected after rising four pixels and grants 1,000 points and about 12 seconds of contact protection. While active, touching Goombas, Koopas, or shells knocks them out. The player cycles through the area's alternate palettes and the Starman theme temporarily overrides the area music. The effect clears on pipe transfer, flagpole grab, and death. Clearing at the flagpole grab is a deliberate difference from the NES.

Timed multi-coin rewards use independent, fixed 231-physics-tick windows instead of the NES's shared, phase-dependent timer. Loading or hitting another block cannot alter an existing window. Pause and unloaded areas freeze remaining time; death follows the existing progress-reset policy.

## Shared entity registry

Add standard marker-to-scene mappings to **BaseLevel: Entity Scenes** in scenes/levels/base/base_level.tscn. Levels inherit this registry. Do not create a per-level dictionary override: Godot replaces the inherited dictionary rather than merging entries. Levels own their painted placements and reward overrides.

The game uses 256×240 logical framing with window-resolution canvas_items rendering. The bordered, resizable window starts at 768×720; fractional aspect-preserving scaling fits other sizes with bars as needed. Shader masks can render smoothly while foreground artwork uses nearest sampling.

## Source configuration and ownership

`Game.stages` defines completion order and currently lists 1-1 followed by 1-2. **Game → Start Stage Override** selects the starting BaseLevel scene for new runs. Leave it empty to use the first entry. Selecting a registered scene starts at its position in the list. A scene outside the list returns to the title after ordinary completion. The title backdrop is configured separately. Single-stage test fixtures assign `game.stages.assign([scene])`.

Use typed GameHandler methods/properties and `player_status` for score, coins, lives, form, top score, stage label, and timer values. Generic `set_session_value()` / `get_session_value()` are for run metadata such as area/arrival IDs; reserved-key writes are rejected. The existing `session_value_changed` signal carries both typed-value and metadata notifications.

LevelSpawnRegistry keeps ten enemy slots and one independent power-up slot. These are code-defined limits. Ordinary painted spawners attempt once per area load and do not retry after rejection. Reward blocks may explicitly replace the current power-up. Unlisted categories remain unlimited and untracked.

## Deliberate gameplay differences

Enemy stomp scoring omits the NES shared StompTimer score modifier. A stomped Koopa instead has a shell-local 12-tick grace window; a kick does not refresh it. These rules are separate from the independent timed-coin windows above.

Area and pipe arrivals use a shared 17-active-physics-tick hold (about 0.28 seconds at 60 Hz), including grounded arrivals. Animated exits wait before emergence and release controls immediately afterward. Direct arrivals apply the input lock after placement. 1-2 also uses the hold for early respawns at its underground entrance, matching the observed duration in Mesen. The NES underground entrance releases input at a Y threshold. Ordinary starts and other respawns retain immediate normal control.
