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

Configure **Presentations → PipeOpening** with the intro area, painted castle cell, and the sideways pipe's **Entrance ID**. A fresh entry spawns at the castle doorway and walks into that pipe automatically. In 1-2, the pipe targets `main / arrival`, which uses **Areas → MainArea → Arrival**. Early deaths restart at **Players → PlayerSpawn**. Move each marker to set its placement independently.

In 1-2, the first upright pipe in MainArea leads to BonusArea's Arrival. The sideways pipe at the end of the coin room returns through MainArea's third upright pipe. The sideways pipe near the end of MainArea leads to the upright pipe in SurfaceArea.

Set **Stage Scene** on a transport destination for a cross-stage warp. After pipe entry, the stage completion flow loads that scene at its normal start. All three 1-2 Warp Zone pipes currently share a destination of 1-1.

Mario and Luigi carry their current form through normal stage completion and cross-stage warps. The next stage applies the form before the first pose or opening presentation. Death respawns use the stage's starting form.

### Place a Warp Zone

Instance `scenes/entities/warp_zone/warp_zone.tscn` under the area's **WorldObjects**. Position **RevealMarker** where the camera's left edge should reveal the banner. Place one or more `warp_zone_pipe.tscn` instances under **Pipes**. Set each pipe's **Display Text** and **Destination → Stage Scene** independently. The text follows the pipe when it moves.

Set **Pipe Occupant** on the zone to give its pipes plants before the reveal. Revealing the zone removes those occupants and enables the configured entrances. The 1-2 instance shows **1 1 1** because each pipe routes to 1-1.

**Presentations → FlagpoleEnding** binds to the painted flagpole and castle by area ID and cell. In 1-2, the ending uses the SurfaceArea markers. The castle in IntroArea provides the opening doorway. In Overworld areas, paint **Large Castle (10x11)** on **EntityLayout** for a tall finish like 1-3. The side walls extend two tiles left of the stamped cell. Set **Castle Cell** to the cell where you painted the stamp. This variant supplies the left doorway and shares the castle flag and fireworks sequence.

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

1-1 uses a marker at `(1328, 208)` and a camera-left threshold of `1280`. 1-2 uses `(1584, 208)` and `1536`. These coordinates are relative to each stage's main area. At a halfway restart, the camera starts at the threshold and Mario's sprite starts 40 px from the left edge. Main-area deaths before the threshold use PlayerSpawn. Side-area deaths use the active camera's world position, so 1-1's authored secret room restarts at PlayerSpawn and 1-2's authored bonus room uses the halfway marker.

On the first main-area load of a halfway restart, EnemyLayout placements with a spawn trigger left of the last visible pixel are skipped for that area load. In 1-2 this skips the Goomba triplet near the checkpoint. Enemies with triggers at or beyond the right edge and occupants attached to pipes can spawn normally.

## Known reference differences

Choose **Apply Tiered Power-Up Reward** in the **EntityLayout** block reward brush, then click a painted question block, hidden question block, reward brick, or alternate reward brick. The translucent red mushroom marks the tiered reward. The block chooses a Super Mushroom for Small Mario or Luigi and a Fire Flower for Super or Fire when it releases the reward. Previously painted Super Mushroom assignments use the same tiered behavior. Coin remains the default.

Both items grant 1,000 points on pickup. Super Mushroom grows Small to Super. Fire Flower grows Small to Super, upgrades Super to Fire, and grants points to an already-Fire player.

Choose **Apply Starman Reward** in the same brush to paint a fixed star reward. The translucent star uses the area's item art. Starman can be collected after rising four pixels and grants 1,000 points and about 12 seconds of contact protection. While active, touching Goombas, Koopas, or shells knocks them out. The player cycles through the area's alternate palettes and the Starman theme temporarily overrides the area music. The effect clears on pipe transfer, flagpole grab, and death. Clearing at the flagpole grab is a deliberate difference from the NES.

Timed multi-coin rewards use independent, fixed 231-physics-tick windows instead of the NES's shared, phase-dependent timer. Loading or hitting another block cannot alter an existing window. Pause and unloaded areas freeze remaining time; death follows the existing progress-reset policy.

## Paint pipe occupants

Select **EntityLayout** and paint a vertical **Pipe Entrance (2×2)**. In the 2D toolbar, choose **Apply Green Piranha Plant** and click either half of the pipe mouth. A translucent preview uses the area theme and stays visible when you switch brushes. Use **Clear Pipe Spawn** on the mouth to remove it. Both brushes support undo and redo.

Each mouth has one occupant entry. Decorative, entrance, and exit pipes can all host a plant. Pipe destinations are configured separately. The plant uses an enemy slot and shares the one-attempt-per-area-load rule with other painted enemies.

## Shared entity registry

Add standard marker-to-scene mappings to **BaseLevel: Entity Scenes** in scenes/levels/base/base_level.tscn. Levels inherit this registry. Do not create a per-level dictionary override: Godot replaces the inherited dictionary rather than merging entries. Levels own their painted placements and reward overrides.

The game uses 256×240 logical framing with window-resolution canvas_items rendering. The bordered, resizable window starts at 768×720; fractional aspect-preserving scaling fits other sizes with bars as needed. Shader masks can render smoothly while foreground artwork uses nearest sampling.

## Source configuration and ownership

`Game.stages` defines completion order and currently lists 1-1, 1-2, and 1-3. Clearing the final registered stage returns to the title. **Game → Start Stage Override** selects the starting BaseLevel scene for new runs. Leave it empty to use the first entry. Selecting a registered scene starts at its position in the list. A scene outside the list returns to the title after ordinary completion. The title backdrop is configured separately. Single-stage test fixtures assign `game.stages.assign([scene])`.

Use typed GameHandler methods/properties and `player_status` for score, coins, lives, form, top score, stage label, and timer values. Generic `set_session_value()` / `get_session_value()` are for run metadata such as area/arrival IDs; reserved-key writes are rejected. The existing `session_value_changed` signal carries both typed-value and metadata notifications.

In `scenes/main/game.tscn`, select **Game → Gameplay → Enemy Limit** to set the number of enemies that can be active at once. The default is **5** and standalone level previews also use five. Set it to **0** to disable enemy spawns. The single power-up slot is independent. Ordinary painted spawners attempt once per area load and do not retry after rejection. Reward blocks may explicitly replace the current power-up. Unlisted categories remain unlimited and untracked.

Paint one **Goomba Pair Spawner**, **Goomba Triplet Spawner**, or **Green Koopa Pair Spawner** marker on the 16×16 **EnemyLayout** at the first member's placement. The marker creates the group together at the camera's right edge, with members 24 pixels apart. If the group runs out of enemy slots during activation, the remaining members are skipped for that area load.

Paint **Red Koopa Spawner** on **EnemyLayout** in the cell immediately above its support. A walking Red Koopa turns at ledges, and its kicked shell can roll off them.

Paint **Red Parakoopa Spawner** on **EnemyLayout** to place a Red Koopa that flies vertically. The marker sets its starting position. Its flight range follows the reference's starting-height rule. The first stomp removes its wings and awards 400 points, after which it walks and uses the shared shell states. In 1-3 the two markers are at (74, 4) and (114, 5).

## Place moving lifts

Instance `scenes/entities/spawners/lift_spawner.tscn` under the area's **WorldObjects**. Its X position is the lift's left edge. Put the marker at the incoming edge and set **Direction** to **Up** or **Down**. For a 240 px view starting at Y=0, use Y=248 for Up or Y=−8 for Down.

**Initial Offsets** lists each lift's starting distance from the marker, in pixels along the travel direction. The default is one lift at offset 0. Add distinct offsets to stagger multiple lifts in the same lane. Each lift cycles independently, with a replacement at the incoming edge when it exits the far edge. Lifts use no enemy slots.

For a single back-and-forth lift, instance `scenes/entities/spawners/single_lift_spawner.tscn` under **WorldObjects** and choose **Horizontal** or **Vertical** in **Axis**. Place the node at the left end of the platform's starting surface. A horizontal lift starts moving left. A vertical lift starting in the upper half of the reference playfield moves down first. The camera activates each spawner once per area visit. The lift is freed when it leaves the camera's cleanup bounds.

## Deliberate gameplay differences

Enemy stomp scoring omits the NES shared StompTimer score modifier. A stomped Koopa instead has a shell-local 12-tick grace window; a kick does not refresh it. These rules are separate from the independent timed-coin windows above.

Area and pipe arrivals use a shared 17-active-physics-tick hold (about 0.28 seconds at 60 Hz), including grounded arrivals. Animated exits wait before emergence and release controls immediately afterward. Direct arrivals apply the input lock after placement. Death respawns restore control when the stage is revealed.
