# Setup

## Run the project

1. Open `project.godot` in Godot 4.7. Local regression runs use Godot 4.7.2.
2. Press **F5** to run the game from the title screen.
3. Press **Enter** or controller **Start** to load 1-1.

Open `scenes/levels/test_level.tscn` and press **F6** to run the one-screen sandbox. The same scene serves as the title backdrop with gameplay disabled. In the sandbox, walk right to intercept the moving 1-Up mushroom to collect an extra life.

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | Left and Right arrows | D-pad |
| Jump | Space | A / bottom face button |
| Run | Left Shift | X / left face button |
| Enter a vertical pipe | Down | D-pad Down |
| Start | Enter | Start / Menu |

Hold Jump for a higher jump. Press the opposite direction while moving to skid. Sideways pipe entrances activate when you walk into their opening.

## Edit a level

Open `scenes/levels/worlds/world 1/1-1.tscn`. Expand **Areas → MainArea → Layouts**. Use **GroundLayout** for solid terrain, **DecorationLayout** for scenery, and **EntityLayout** for entity stamps. Each layer uses the same 16×16 grid. Keep nested areas editable so scene overrides survive saving.

Paint question blocks on **EntityLayout**. Each placed block contains one coin.

Paint a pipe stamp, then configure its destination on the area. To test area switching, enter the vertical pipe in 1-1 and walk into the sideways pipe in the secret area. See [configuration](configuration.md#areas-and-pipe-routes).

In the 2D editor, question blocks show a translucent reward icon. Select EntityLayout and choose **Apply 1-Up Reward** from the 2D toolbar, then click a painted question block. Choose **Apply Coin Reward** to clear an override. Reward edits support undo and redo. Choose **Paint Tiles** to return to normal painting. Reward overrides are keyed by cell, so clear the override before erasing, moving, or replacing a configured block.
