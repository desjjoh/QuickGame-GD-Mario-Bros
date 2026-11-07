# Setup

## Run the project

1. Open `project.godot` in Godot 4.7. Local regression runs use Godot 4.7.2.
2. Press **F5** to run the game from the title screen.
3. Press **Enter** or controller **Start** to load 1-1.

Open `scenes/levels/test_level.tscn` and press **F6** to run the one-screen sandbox. The same scene serves as the title backdrop with gameplay disabled.

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | Left and Right arrows | D-pad |
| Jump | Space | A / bottom face button |
| Run | Left Shift | X / left face button |
| Enter a vertical pipe | Down | D-pad Down |
| Start | Enter | Start / Menu |
| Pause / resume during gameplay | Enter | Start / Menu |

Hold Jump for a higher jump. Press the opposite direction while moving to skid. Sideways pipe entrances activate when you walk into their opening.

Pause keeps the current screen visible and freezes gameplay, animation, and ordinary audio. Release Start, then press it again to resume. A short lockout prevents rapid toggles. Pause is unavailable on the title screen and during active screen transitions. Pipe entry/emergence, death, and level-ending animations remain pausable. Standalone F6 levels also support pause.

## Edit a level

Open `scenes/levels/worlds/world 1/1-1.tscn`. Expand **Areas → MainArea → Layouts**. Use **GroundLayout** for solid terrain, **DecorationLayout** for scenery, **EntityLayout** for blocks and other entity stamps, and **EnemyLayout** for single or paired Goomba spawners. EnemyLayout uses an 8×8 grid. The other layers use 16×16. Keep nested areas editable so scene overrides survive saving.

Paint question blocks, **Reward Brick**, or **Reward Brick Alt** on **EntityLayout**. Each defaults to one coin. Reward bricks start with a static brick texture and become used blocks after releasing their reward; ordinary bricks remain separate.

Paint a pipe stamp, then configure its destination on the area. To test area switching, enter the vertical pipe in 1-1 and walk into the sideways pipe in the secret area. See [configuration](configuration.md#areas-and-pipe-routes).

In the 2D editor, question blocks show a translucent reward icon. Select EntityLayout and choose **Apply 1-Up Reward** from the 2D toolbar, then click a painted question block, hidden question block, or reward brick. Choose **Apply Timed Coins Reward** for a 231-tick multi-coin window, shown as a translucent coin stack. Choose **Apply Coin Reward** to clear an override. Reward edits support undo and redo. Choose **Paint Tiles** to return to normal painting. Reward overrides are keyed by cell, so clear the override before erasing, moving, or replacing a configured block.

The green mushroom spawner is no longer in the EntityLayout painting palette. Painting standalone power-ups is deferred; no replacement layer has been added. The 1-Up reward brush still configures block contents.
