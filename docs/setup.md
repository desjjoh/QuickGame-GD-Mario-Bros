# Setup

## Run the project

1. Open `project.godot` in Godot 4.7. Local regression runs use Godot 4.7.2.
2. Press **F5** to run the game from the title screen.
3. Press **Tab** or controller **Select** to switch between **1 PLAYER GAME** for Mario and **2 PLAYER GAME** for a solo Luigi run. Press **Enter** or controller **Start** to load 1-1.

Open `scenes/levels/worlds/world 1/1-1.tscn` and press **F6** to run 1-1 directly. It is also the default title backdrop, with gameplay disabled. Leave **Game → Presentation → Title Background** empty to use the first entry in **Stages**, or assign another level to override it.

Clearing 1-1 starts 1-2 at the castle doorway. The player walks into the opening pipe automatically. Clearing 1-2 loads the 1-3 starter scene, which has one overworld area with placeholder ground. To start at a later level, set **Game → Start Stage Override** in `scenes/main/game.tscn`. Clear the field to start at 1-1 again.

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | Left and Right arrows | D-pad |
| Jump | Space | A / bottom face button |
| Run | Left Shift | X / left face button |
| Enter a vertical pipe | Down | D-pad Down |
| Start | Enter | Start / Menu |
| Pause / resume during gameplay | Enter | Start / Menu |

Hold Jump for a higher jump. Press the opposite direction while moving to skid. Sideways pipe entrances activate when you walk into their opening. Area arrivals include a 17-physics-tick hold. Direct placements ignore movement input while Mario falls normally. Animated pipe arrivals wait inside the exit for 17 ticks before emerging, with immediate control after the animation. Pause freezes the hold. 1-2 also applies the hold when an early death restarts Mario at the underground drop.

Pause keeps the current screen visible and freezes gameplay, animation, and ordinary audio. Release Start, then press it again to resume. A short lockout prevents rapid toggles. Pause is unavailable on the title screen and during active screen transitions. Pipe entry/emergence, death, and level-ending animations remain pausable. Standalone F6 levels also support pause.

## Edit a level

Open `scenes/levels/worlds/world 1/1-1.tscn`. Expand **Areas → MainArea → Layouts**. Use **GroundLayout** for solid terrain, **DecorationLayout** for scenery, **EntityLayout** for blocks and other entity stamps, and **EnemyLayout** for single/paired Goomba spawners and Green Koopa spawners. EnemyLayout and the other layout layers use 16×16 grids. Paint ground enemies in the cell immediately above their supporting terrain; their feet start on its top surface. Keep nested areas editable so scene overrides survive saving. 1-1 has its reference Green Koopa at EnemyLayout cell (107, 12), world origin (1712, 192).

Paint question blocks, **Reward Brick**, or **Reward Brick Alt** on **EntityLayout**. Each defaults to one coin. Reward bricks start with a static brick texture and become used blocks after releasing their reward; ordinary bricks remain separate.

Paint a pipe stamp, then configure its destination on the area. To test area switching, enter the vertical pipe in 1-1 and walk into the sideways pipe in the secret area. See [configuration](configuration.md#areas-and-pipe-routes).

In the 2D editor, question blocks show a translucent reward icon. Select EntityLayout and choose **Apply 1-Up Reward** from the 2D toolbar, then click a painted question block, hidden question block, or reward brick. Choose **Apply Tiered Power-Up Reward** for a Super Mushroom when Small or a Fire Flower when Super or Fire or **Apply Timed Coins Reward** for a 231-tick multi-coin window, shown as a translucent coin stack. Choose **Apply Coin Reward** to clear an override. Reward edits support undo and redo. Choose **Paint Tiles** to return to normal painting. Reward overrides are keyed by cell, so clear the override before erasing, moving, or replacing a configured block.

For Overworld trees, paint **Tree tops** on **GroundLayout**. Use the left and right caps with repeatable middle tiles. Paint **Tree trunks** on **DecorationLayout** below the top. Trunks allow characters to pass through and stay outside the shadow effect.

EntityLayout is for interactable world elements. Standalone power-up painting is not enabled; use the reward brush to place 1-Ups or tiered power-ups inside blocks.

Choose **Green Koopa Spawner** on EnemyLayout to try the Green Koopa. It uses the selected area theme, walks and falls, and turns at walls or enemies. Walking contact damages Mario. Stomping rebounds Mario, awards 100 points, and leaves a stationary shell. Touch a stationary shell to kick it away from Mario. Moving shells rebound from walls, defeat enemies, and can be stopped by a stomp. A stationary shell warns before waking back into a walking Koopa. Its feet align with the existing enemy placement origin; taller artwork extends above it.

## Preview Mario forms

1-1 currently uses the default Small Mario. Set **Player Start Configuration** to `assets/player/forms/super.tres` to preview Super with the same actor. Select the 1-1 root and inspect Player Start Configuration to choose Super or Small for F6. Open the existing Mario scene and inspect Starting Form for its default, currently Small; normal 1-1 still starts Small. The form's artwork/contact profile applies without replacing the player scene.

Super now supports standing probes, crouching, crouch jumping, and reference-style uncrouching push-out. Hold Down alone on the ground to crouch; crouch is retained during a jump even after releasing Down. Grounded Down plus a horizontal button clears crouch and directional input, following the reference. The short physics body supplies floor support while extra probes handle Super's upper collisions. Super Mushroom collection grows Small Mario; enemy damage shrinks Super and starts damage protection. Super can break ordinary and alternate bricks for debris and 50 points without a score popup. Tiered blocks release Fire Flowers for Super and Fire players. Fire uses the Super movement and collision profiles.

## Rebuild paint-marker previews

Castle and flagpole builders read their authored scene TileMaps; pipe builders use their atlas resources. All three rebuild Overworld, Underground, and Castle previews through `scripts/marker_preview.gd`.

```powershell
& 'C:/path/to/Godot_console.exe' --headless --path . --script res://scripts/build_castle_marker.gd
& 'C:/path/to/Godot_console.exe' --headless --path . --script res://scripts/build_flagpole_marker.gd
& 'C:/path/to/Godot_console.exe' --headless --path . --script res://scripts/build_pipe_marker.gd
```

Append `-- --check` to compare generated pixels with the saved previews without writing images. Failed checks return a nonzero exit code. Let Godot reimport rebuilt PNGs; marker IDs, tile grids, and placed entities are unchanged.

## Documentation layout

The README and seven guides in `docs/` describe current behavior. Detailed walkthroughs, reference investigations, settings approvals, decisions, and history are kept locally in the top-level `.archive/`, ignored by Git and Godot. Keep current instructions in the public guides and append internal milestone notes to `.archive/history.md`. Required test data belongs in committed `tests/fixtures/`, not the private archive.
